module RaftNode where

import Control.Concurrent.MVar
import Control.Concurrent.Chan
import Control.Concurrent (forkIO, threadDelay, myThreadId)

import Control.Monad (forever)

import GHC.Conc.Sync (ThreadId)
import Thrift
import Thrift.Protocol
import Thrift.Protocol.Binary
import Thrift.Transport
import Thrift.Transport.Handle
import Thrift.Server
import Network
import Data.Maybe
import Data.Int

import System.IO
import System.Random

import ClusterNode_Iface
import ClusterNode
import qualified ClusterNode_Client as Client
import qualified Rafths_Types as T

data Peer = Peer { host :: String, port :: Int } deriving (Eq)

data NodeHand = NodeHand { peers :: [Peer], state :: MVar State, chan :: Chan Event }

data State = Follower Props 
           | Candidate Props 
           | Leader Props [Int] [Int]

data Event = ElectionTimeout -- whenever election timeout elapses without receiving heartbeat/grant vote
           | ReceivedMajorityVote -- candidate received majority, become leader
           | ReceivedAppendFromLeader -- candidate contacted by leader during election, become follower

data LogEntry = LogEntry { key :: String , value :: String }

data Props = Props {
  currentTerm :: Int64,
  votedFor :: Maybe Int32,
  logEntries :: [LogEntry],
  commitIndex :: Int32,
  lastApplied :: Int32
}

emptyProps :: Props
emptyProps = Props 0 Nothing [] 0 0

getProps :: State -> Props
getProps (Follower p) = p
getProps (Candidate p) = p
getProps (Leader p _ _) = p

start :: PortNumber -> [Peer] -> IO ()
start port peers = do
  hand <- newNodeHandler peers

  chan <- newChan :: IO (Chan String)

  -- write to channel periodically on a new thread
  forkIO $ forever $ do
    state <- getState hand

    timeout <- randomElectionTimeout 1000 -- reset this timeout whenever we receive heartbeat from leader or granted vote to candidate
    delayMs timeout
    writeChan chan "hi!"

  -- read from channel on a new thread (blocks current thread)
  forkIO $ forever $ do
    readChan chan >>= print 

  -- spin up server on main thread
  print "Starting server..."
  _ <- runBasicServer hand ClusterNode.process port -- todo runThreadedServer
  print "Server terminated!"


newNodeHandler :: [Peer] -> IO NodeHand
newNodeHandler peers = do
  state <- newMVar $ Follower emptyProps
  chan <- newChan :: IO (Chan Event)
  pure $ NodeHand peers state chan

getState :: NodeHand -> IO State
getState h = readMVar . state $ h

setState :: NodeHand -> State -> IO ()
setState h s = do
  let mvar = state h
  modifyMVar_ mvar (const $ pure s)

-- RPC Handlers
instance ClusterNode_Iface NodeHand where
  requestVote = requestVoteHandler
  appendEntries = appendEntriesHandler

requestVoteHandler :: NodeHand -> T.VoteRequest -> IO T.VoteResponse
requestVoteHandler handler request = do
  print "requestVote()"
  state <- getState handler
  let p = getProps state
  pure $ newVoteResponse (currentTerm p) (shouldGrant p request)

appendEntriesHandler :: NodeHand -> T.AppendRequest -> IO T.AppendResponse
appendEntriesHandler handler request = do
  pure T.AppendResponse { T.appendResponse_term = 1, T.appendResponse_success = True }

---
newVoteResponse :: Int64 -> Bool -> T.VoteResponse
newVoteResponse term grant = T.VoteResponse { T.voteResponse_term = term, T.voteResponse_granted = grant }

shouldGrant :: Props -> T.VoteRequest -> Bool
shouldGrant p req = 
  if currentTerm p > T.voteRequest_term req then False else grant
  where
    voted = maybe True (== T.voteRequest_candidateId req) (votedFor p)
    upToDate = (length $ logEntries $ p) - 1 <= (fromIntegral $ T.voteRequest_lastLogIndex req)
    grant = voted && upToDate


-- Create client RPC stub referencing another node in the cluster
newThriftClient :: String -> Integer -> IO (BinaryProtocol Handle, BinaryProtocol Handle)
newThriftClient host port = do
  transport <- hOpen (host, (PortNumber . fromInteger $ port))
  let proto = BinaryProtocol transport
  pure (proto, proto)

-- To begin an election, a follower increments its current
-- term and transitions to candidate state. It then votes for
-- itself and issues RequestVote RPCs in parallel to each of
-- the other servers in the cluster. A candidate continues in
-- this state until one of three things happens: (a) it wins the
-- election, (b) another server establishes itself as leader, or
-- (c) a period of time goes by with no winner. 
-- These outcomes are discussed separately in the paragraphs below
beginElection :: IO State
beginElection = do
  mid <- myThreadId
  print "beginElection on thread "
  print mid
  pure $ Candidate emptyProps

randomElectionTimeout :: Int -> IO Int
randomElectionTimeout t = randomRIO (t, 2 * t)

delayMs :: Int -> IO ()
delayMs ms = threadDelay $ ms * 1000


