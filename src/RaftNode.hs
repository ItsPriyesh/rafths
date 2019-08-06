{-# LANGUAGE DeriveGeneric #-}

module RaftNode where

import GHC.Generics (Generic)
import GHC.Conc.Sync (ThreadId)
import Data.Hashable
import Data.Atomics.Counter
import Data.Maybe
import Data.Int
import Control.Concurrent.MVar
import Control.Concurrent.Chan
import Control.Concurrent (forkIO, threadDelay, myThreadId)
import Control.Monad (forever)
import Thrift
import Thrift.Protocol
import Thrift.Protocol.Binary
import Thrift.Transport
import Thrift.Transport.Handle
import Thrift.Transport.Framed
import Thrift.Server

import Network
import Network.HostName
import System.IO
import System.Random

import ClusterNode_Iface
import ClusterNode
import qualified ClusterNode_Client as Client
import qualified Rafths_Types as T

import ThriftConverter

data Peer = Peer { host :: String, port :: Int } deriving (Eq, Show, Generic)
instance Hashable Peer

data NodeHand = NodeHand { peers :: [Peer], state :: MVar State, chan :: Chan Event }

data State = Follower Props 
           | Candidate Props 
           | Leader Props [Int] [Int]
           deriving Show

nextIndex (Leader _ n _) = n
matchIndex (Leader _ _ n) = n

data Event = ElectionTimeout -- whenever election timeout elapses without receiving heartbeat/grant vote
           | ReceivedMajorityVote -- candidate received majority, become leader
           | ReceivedAppend -- candidate contacted by leader during election, become follower
           deriving Show

data LogEntry = LogEntry { keyVal :: (String, String), term :: Int } deriving Show

data Props = Props {
  self :: Peer,
  currentTerm :: Int64,
  votedFor :: Maybe Int32,
  logEntries :: [LogEntry],
  commitIndex :: Int32,
  lastApplied :: Int32
} deriving Show

newProps :: Peer -> Props
newProps self = Props self 0 Nothing [] 0 0

getProps :: State -> Props
getProps (Follower p) = p
getProps (Candidate p) = p
getProps (Leader p _ _) = p

start :: PortNumber -> [Peer] -> IO ()
start port peers = do
  hand <- newNodeHandler port peers

  -- write to channel periodically on a new thread
  forkIO $ forever $ do
    -- c <- chan hand

    timeout <- randomElectionTimeout -- reset this timeout whenever we receive heartbeat from leader or granted vote to candidate
    delayMs timeout
    writeChan (chan hand) ElectionTimeout

  -- read from channel on a new thread (blocks current thread)
  forkIO $ forever $ do
    -- c <- chan hand
    event <- readChan $ chan hand
    state <- getState hand
    print "handling :"
    print event
    print state
    newState <- handleEvent state event
    setState hand newState

  -- spin up server on main thread
  print "Starting server..."
  _ <- runThreadedServer acceptor hand ClusterNode.process (PortNumber $ fromIntegral port)
  print "Server terminated!"

  where
    acceptor sock = do
      (h, _, _) <- (accept sock)
      t <- openFramedTransport h
      return (BinaryProtocol t, BinaryProtocol t)


newNodeHandler :: PortNumber -> [Peer] -> IO NodeHand
newNodeHandler port peers = do
  host <- getHostName
  state <- newMVar $ Follower (newProps $ Peer host (fromIntegral $ port))
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
requestVoteHandler h req = do
  print "requestVote()"
  state <- getState h
  let p = getProps state
  pure $ newVoteResponse (currentTerm p) (shouldGrant p req)


shouldGrant :: Props -> T.VoteRequest -> Bool
shouldGrant p req = 
  if currentTerm p > T.voteRequest_term req then False
  else voted && localLast <= candidateLast
  where
    voted = maybe True (== T.voteRequest_candidateId req) (votedFor p)
    localLast = (length $ logEntries p) - 1
    candidateLast = fromIntegral $ T.voteRequest_lastLogIndex req

appendEntriesHandler :: NodeHand -> T.AppendRequest -> IO T.AppendResponse
appendEntriesHandler h req = do
  print "appendEntries()"
  writeChan (chan h) ReceivedAppend
  state <- getState h
  let p = getProps state
  pure $ newAppendResponse (currentTerm p) True


-- shouldAppendEntries :: Props -> T.AppendRequest -> Bool
-- shouldAppendEntries p req =
--   if currentTerm p > T.appendRequest_term req then False
--   else
--     let log = logEntries p
--     if T.appendRequest_prevLogIndex >= (length log - 1)) || ((term (log !! T.appendRequest_prevLogIndex)) != T.appendRequest_prevLogTerm) then False
--     else True

-- Create client RPC stub referencing another node in the cluster
newThriftClient :: String -> Int -> IO (BinaryProtocol Handle, BinaryProtocol Handle)
newThriftClient host port = do
  transport <- hOpen (host, PortNumber . fromIntegral $ port)
  let proto = BinaryProtocol transport
  pure (proto, proto)

handleEvent :: State -> Event -> IO State
handleEvent (Follower p) ElectionTimeout = do
  print "converting follower to candidate"
  pure $ newCandidate p

newCandidate p = Candidate p { currentTerm = 1 + currentTerm p}

requestVotes :: Chan Event -> State -> [Peer] -> IO State
requestVotes ch (Candidate p) peers = do
  -- restart election timeout
  forkIO $ do
    timeout <- randomElectionTimeout
    delayMs timeout
    writeChan ch ElectionTimeout

  -- thread safe atomic counter for parallel vote RPCs
  voteCount <- newCounter 1

  -- call requestVote RPC on each peer concurrently
  mapM_ (forkIO . getVote voteCount) (filter (/= self p) peers)

  -- listen for a state transition event
  event <- readChan ch
  electionResult event

  where
    getVote :: AtomicCounter -> Peer -> IO ()
    getVote count peer = do
      vote <- requestVoteFromPeer p peer -- todo check that this fails after a short timeout 
      votes <- if T.voteResponse_granted vote then incrCounter 1 count else readCounter count
      if votes >= majority peers then writeChan ch ReceivedMajorityVote else pure ()

    electionResult ElectionTimeout = requestVotes ch (Candidate p) peers -- stay in same state, start new election
    electionResult ReceivedMajorityVote = pure $ Leader p [] [] -- todo init these arrays properly
    electionResult ReceivedAppend = pure $ Follower p


requestVoteFromPeer :: Props -> Peer -> IO T.VoteResponse
requestVoteFromPeer p peer = do
  c <- newThriftClient (host peer) (port peer)
  let lastLogIndex = (length $ logEntries $ p) - 1
  let lastLogTerm = if lastLogIndex >= 0 then term $ (logEntries p) !! lastLogIndex else 1
  let req = newVoteRequest (hash $ self p) (currentTerm p) lastLogTerm lastLogIndex
  Client.requestVote c req

randomElectionTimeout :: IO Int
randomElectionTimeout = do
  let t = 5 * 1000 -- 5s
  randomRIO (t, 2 * t)

delayMs :: Int -> IO ()
delayMs ms = threadDelay $ ms * 1000

majority :: [Peer] -> Int
majority peers = if even n then 1 + quot n 2 else quot (n + 1) 2
  where n = length $ peers
