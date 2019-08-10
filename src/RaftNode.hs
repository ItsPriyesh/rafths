{-# LANGUAGE DeriveGeneric #-}
--(serve, NodeHand, Peer)
module RaftNode where

import Prelude hiding (log)

import GHC.Generics (Generic)
import GHC.Conc.Sync (ThreadId)
import Data.Hashable
import Data.Atomics.Counter
import Data.Maybe
import Data.Int

import Data.List
import qualified Data.Vector as V

import Control.Concurrent.MVar
import Control.Concurrent.Chan
import Control.Concurrent.Timer
import Control.Concurrent.Suspend.Lifted
import Control.Concurrent (forkIO, threadDelay, myThreadId)
import Control.Monad (forever)

import Network
import Network.HostName

import System.IO
import System.Random

import RaftNodeService_Iface
import RaftNodeService
import qualified RaftNodeService_Client as Client
import qualified Rafths_Types as T

import ThriftUtil
import RaftLog
import KeyValueApi

data Peer = Peer { host :: String, port :: Int } deriving (Eq, Show, Read, Generic)

data NodeHand = NodeHand { peers :: [Peer], state :: MVar State, chan :: Chan Event, timer :: TimerIO }

instance KeyValueStore NodeHand where
  get h k = do -- todo
    state <- getState h
    pure Nothing

  put h k v = fmap updateLog (getState h)
    where updateLog (Leader _ _ _) = True
          updateLog (Follower _) = False -- todo otherwise syntax?
          updateLog (Candidate _) = False

  isLeader h = fmap leads (getState h)
    where leads (Leader _ _ _) = True
          leads (Follower _) = False
          leads (Candidate _) = False
  
  getLeader h = fmap leader' (getState h)
    where leader' (Leader p _ _) = Just $ tupled $ self p
          leader' (Follower p) = tupledMaybe p
          leader' (Candidate p) = tupledMaybe p
          tupled p = (host p, port p)
          tupledMaybe p = fmap (tupled . read) (leader p)

data State = Follower Props 
           | Candidate Props 
           | Leader Props [Int] [Int]
           deriving Show

nextIndex (Leader _ n _) = n
matchIndex (Leader _ _ n) = n

toFollower :: State -> State
toFollower (Follower p) = Follower p
toFollower (Candidate p) = Follower p
toFollower (Leader p _ _) = Follower p

-- TODO use lens
getProps :: State -> Props
getProps (Follower p) = p
getProps (Candidate p) = p
getProps (Leader p _ _) = p

setProps :: State -> Props -> State
setProps (Follower _) p  = Follower p
setProps (Candidate _) p = Candidate p
setProps (Leader _ n m) p =  Leader p n m

data Event = ElectionTimeout -- whenever election timeout elapses without receiving heartbeat/grant vote
           | ReceivedMajorityVote -- candidate received majority, become leader
           | ReceivedAppend -- candidate contacted by leader during election, become follower
           deriving Show

data Props = Props {
  self :: Peer,
  log :: Log,
  currentTerm :: Int64,
  leader :: Maybe String,
  votedFor :: Maybe String,
  commitIndex :: Int,
  lastApplied :: Int
} deriving Show

newProps :: Peer -> Props
newProps self = Props self [] 0 Nothing Nothing 0 0

restartElectionTimeout :: NodeHand -> IO ()
restartElectionTimeout h = do
  timeout <- randomElectionTimeout
  print $ "restarting election timeout " ++ show timeout
  oneShotStart (timer h) (onComplete >>= const (pure ())) (msDelay timeout)
  pure ()
  where
    onComplete = forkIO $ do
      print "timeout complete! writing ElectionTimeout event"
      writeChan (chan h) ElectionTimeout

heartbeatPeriodμs = 5 * 10^6

serve :: PortNumber -> PortNumber -> [Peer] -> IO ()
serve httpPort raftPort peers = do
  hand <- newNodeHandler raftPort peers

  forkIO $ serveHttpApi httpPort hand

  restartElectionTimeout hand

  forkIO $ forever $ do
    event <- readChan $ chan hand
    state <- getState hand
    
    print $ "receive! " ++ show event ++ " state: " ++ show state
    
    state' <- handleEvent hand state event
    setState hand state'

    print $ "handled! state': " ++ show state'
    print $ "--------------------------------"

  -- hearbeat thread, every couple seconds check the current state, if its a leader send heartbeats
  forkIO $ forever $ do
    threadDelay heartbeatPeriodμs
    state <- getState hand
    print $ "heartbeat thread: state = " ++ show state
    case state of (Leader p _ _) -> sendHeartbeats p peers
                  _ -> pure ()

  _ <- runServer hand RaftNodeService.process raftPort
  print "Server terminated!"

sendHeartbeats :: Props -> [Peer] -> IO ()
sendHeartbeats p peers = do
    clients <- mapM (\a -> newThriftClient (host a) (port a)) (filter (/= self p) peers)
    mapM_ (forkIO . heartbeat) clients
    where
      req = newHeartbeat (currentTerm p) (show $ self p) (commitIndex p)
      heartbeat c = do
        response <- Client.appendEntries c req
        pure ()

newNodeHandler :: PortNumber -> [Peer] -> IO NodeHand
newNodeHandler port peers = do
  host <- getHostName
  state <- newMVar $ Follower (newProps $ Peer host (fromIntegral $ port))
  chan <- newChan :: IO (Chan Event)
  timer <- newTimer
  pure $ NodeHand peers state chan timer

getState :: NodeHand -> IO State
getState h = readMVar . state $ h

setState :: NodeHand -> State -> IO ()
setState h s = modifyMVar_ (state h) (const $ pure s)

setStateProps :: NodeHand -> State -> Props -> IO ()
setStateProps h s p = setState h (setProps s p)

-- RPC Handlers
instance RaftNodeService_Iface NodeHand where
  requestVote = requestVoteHandler
  appendEntries = appendEntriesHandler

requestVoteHandler :: NodeHand -> T.VoteRequest -> IO T.VoteResponse
requestVoteHandler h r = do
  print "RPC: requestVote()"
  state <- getState h
  let p = getProps state
  
  if voteRequestTerm r > currentTerm p then
    setState h (Follower p { currentTerm = voteRequestTerm r })
  else pure ()

  let grant = shouldGrant p r
  if grant then do
    restartElectionTimeout h
    setStateProps h state p { votedFor = Just $ candidateId r }
  else pure ()
  
  pure $ newVoteResponse (currentTerm p) grant

shouldGrant :: Props -> T.VoteRequest -> Bool
shouldGrant p r = 
  if currentTerm p > voteRequestTerm r then False
  else currentTerm p == voteRequestTerm r && 
       requestLastLogTerm r >= (fromIntegral $ lastTerm $ log p) && 
       requestLastLogIndex r >= (fromIntegral $ lastIndex $ log p) && 
       maybe True (== candidateId r) (votedFor p)

appendEntriesHandler :: NodeHand -> T.AppendRequest -> IO T.AppendResponse
appendEntriesHandler h r = do
  print "RPC: appendEntries()"
  restartElectionTimeout h
  writeChan (chan h) ReceivedAppend
  state <- getState h
  let p = getProps state
  if currentTerm p > appendRequestTerm r then
    pure $ newAppendResponse (currentTerm p) False
  else do -- update our term, become a follower, and accept entries from the leader
    let p' = p {
      currentTerm = appendRequestTerm r,
      votedFor = Nothing,
      leader = Just $ leaderId r
    }
    if logMatch $ log p then do
      let newLog = appendLog p' (entries r)
      let localCommit = commitIndex p
      let newCommit = if leaderCommit > localCommit then min leaderCommit (lastIndex newLog) 
                      else localCommit 
      setState h (Follower p' { log = newLog, commitIndex = newCommit })
      pure $ newAppendResponse (currentTerm p') True
    else do
      setState h (Follower p')
      pure $ newAppendResponse (currentTerm p') False
  where
    logMatch l = (prevLogIndex r) /= -1 && termMatchedAtIndex l (prevLogTerm r) (prevLogIndex r)
    appendLog p entries = append (log p) (prevLogIndex r + 1) entries
    leaderCommit = leaderCommitIndex r
    
handleEvent :: NodeHand -> State -> Event -> IO State
handleEvent h (Follower p) ElectionTimeout = do
  print "follower timed out! becoming candidate and starting election"
  let state = newCandidate p
  setState h state
  requestVotes h state
handleEvent h (Candidate p) ElectionTimeout = do
  print "timed out during election! restarting election"
  pure $ newCandidate p

-- Increments term and becomes Candidate
newCandidate :: Props -> State
newCandidate p = Candidate p { currentTerm = 1 + currentTerm p}

requestVotes :: NodeHand -> State -> IO State
requestVotes h (Candidate p) = do
  restartElectionTimeout h
  print "making vote counter"
  voteCount <- newCounter 1
  mapM_ (forkIO . getVote voteCount) (filter (/= self p) (peers h))

  ch <- dupChan $ chan h
  event <- readChan $ ch
  print $ "checking election result for : " ++ show event
  electionResult event

  where 
    getVote :: AtomicCounter -> Peer -> IO ()
    getVote count peer = do
      vote <- requestVoteFromPeer p peer -- todo: timeout
      print $ "got requestVote response! " ++ show vote
      votes <- if T.voteResponse_granted vote then incrCounter 1 count else readCounter count
      if votes >= majority (peers h) then writeChan (chan h) ReceivedMajorityVote else pure ()

    electionResult ElectionTimeout = requestVotes h (Candidate p) -- stay in same state, start new election
    electionResult ReceivedMajorityVote = pure $ Leader p [] [] -- todo init these arrays properly
    electionResult ReceivedAppend = pure $ Follower p

requestVoteFromPeer :: Props -> Peer -> IO T.VoteResponse
requestVoteFromPeer p peer = do
  print $ "creating client to " ++ show peer
  c <- newThriftClient (host peer) (port peer)
  let lastLogIndex = lastIndex $ log p --(length $ logEntries $ p) - 1
  let lastLogTerm = lastTerm $ log p --if lastLogIndex >= 0 then term $ (logEntries p) !! lastLogIndex else 1
  let req = newVoteRequest (show $ self p) (currentTerm p) lastLogTerm lastLogIndex
  print $ "sending request " ++ show req
  Client.requestVote c req

randomElectionTimeout :: IO Int64
randomElectionTimeout = randomRIO (t, 2 * t)
  where t = (5 * 10^3) -- 5s

majority :: [Peer] -> Int
majority peers = if even n then 1 + quot n 2 else quot (n + 1) 2
  where n = length $ peers
