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

import Network
import Network.HostName

import System.IO
import System.Random
import System.Timer.Updatable

import RaftNodeService_Iface
import RaftNodeService
import qualified RaftNodeService_Client as Client
import qualified Rafths_Types as T

import ThriftUtil

data Peer = Peer { host :: String, port :: Int } deriving (Eq, Show, Generic)

instance Hashable Peer

data NodeHand = NodeHand { peers :: [Peer], state :: MVar State, chan :: Chan Event, timer :: Updatable () }

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

serve :: PortNumber -> [Peer] -> IO ()
serve port peers = do
  hand <- newNodeHandler port peers
  
  forkIO $ forever $ do
    event <- readChan $ chan hand
    state <- getState hand
    print $ "receive! " ++ show event ++ " state: " ++ show state
    state' <- handleEvent hand state event
    print $ "handled! state': " ++ show state'
    print $ "--------------------------------"
    setState hand state'

  -- start server and block main
  print "Starting server..."
  _ <- runServer hand RaftNodeService.process port
  print "Server terminated!"

newNodeHandler :: PortNumber -> [Peer] -> IO NodeHand
newNodeHandler port peers = do
  host <- getHostName
  state <- newMVar $ Follower (newProps $ Peer host (fromIntegral $ port))
  chan <- newChan :: IO (Chan Event)
  timeout <- randomElectionTimeout
  print $ "waiting! election timeout = " ++ show timeout
  timer <- parallel (writeChan chan ElectionTimeout) timeout
  pure $ NodeHand peers state chan timer

getState :: NodeHand -> IO State
getState h = readMVar . state $ h

setState :: NodeHand -> State -> IO ()
setState h s = do
  let mvar = state h
  modifyMVar_ mvar (const $ pure s)

-- RPC Handlers
instance RaftNodeService_Iface NodeHand where
  requestVote = requestVoteHandler
  appendEntries = appendEntriesHandler

requestVoteHandler :: NodeHand -> T.VoteRequest -> IO T.VoteResponse
requestVoteHandler h req = do
  print "RPC: requestVote()"
  state <- getState h
  let p = getProps state
  let grant = shouldGrant p req
  if grant then restartElectionTimeout $ timer h else pure ()
  pure $ newVoteResponse (currentTerm p) grant

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
  print "RPC: appendEntries()"
  restartElectionTimeout $ timer h
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

handleEvent :: NodeHand -> State -> Event -> IO State
handleEvent h (Follower p) ElectionTimeout = do
  print "follower timed out! becoming candidate and starting election"
  let state = newCandidate p
  setState h state
  requestVotes state (chan h) (timer h) (peers h)
handleEvent h (Candidate p) ElectionTimeout = do
  print "timed out during election! restarting election"
  pure $ newCandidate p

-- Increments term and becomes Candidate
newCandidate :: Props -> State
newCandidate p = Candidate p { currentTerm = 1 + currentTerm p}

requestVotes :: State -> Chan Event -> Updatable () -> [Peer] -> IO State
requestVotes (Candidate p) ch timer peers = do
  restartElectionTimeout timer
  voteCount <- newCounter 1
  mapM_ (forkIO . getVote voteCount) (filter (/= self p) peers)

  event <- readChan ch
  electionResult event

  where
    getVote :: AtomicCounter -> Peer -> IO ()
    getVote count peer = do
      vote <- requestVoteFromPeer p peer -- todo check that this fails after a short timeout 
      print $ "got requestVote response! " ++ show vote
      votes <- if T.voteResponse_granted vote then incrCounter 1 count else readCounter count
      if votes >= majority peers then writeChan ch ReceivedMajorityVote else pure ()

    electionResult ElectionTimeout = requestVotes (Candidate p) ch timer peers -- stay in same state, start new election
    electionResult ReceivedMajorityVote = pure $ Leader p [] [] -- todo init these arrays properly
    electionResult ReceivedAppend = pure $ Follower p

requestVoteFromPeer :: Props -> Peer -> IO T.VoteResponse
requestVoteFromPeer p peer = do
  print $ "creating client to " ++ show peer
  c <- newThriftClient (host peer) (port peer)
  let lastLogIndex = (length $ logEntries $ p) - 1
  let lastLogTerm = if lastLogIndex >= 0 then term $ (logEntries p) !! lastLogIndex else 1
  let req = newVoteRequest (hash $ self p) (currentTerm p) lastLogTerm lastLogIndex
  print $ "sending request " ++ show req
  Client.requestVote c req

randomElectionTimeout :: IO Int64
randomElectionTimeout = randomRIO (t, 2 * t)
  where t = 5 * 10^6 -- 5s

restartElectionTimeout :: Updatable a -> IO ()
restartElectionTimeout timer = do
  timeout <- randomElectionTimeout
  print $ "restarting election timeout " ++ show timeout
  renewIO timer timeout

majority :: [Peer] -> Int
majority peers = if even n then 1 + quot n 2 else quot (n + 1) 2
  where n = length $ peers
