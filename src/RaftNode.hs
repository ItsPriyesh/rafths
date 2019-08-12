{-# LANGUAGE DeriveGeneric #-}

module RaftNode where

import Prelude hiding (log)
import GHC.Generics (Generic)
import GHC.Conc.Sync (ThreadId)
import Data.Hashable
import Data.Atomics.Counter
import Data.Maybe
import Data.Int
import Data.List
import qualified Data.Map as M
import qualified Data.Vector as V
import Control.Concurrent.MVar
import Control.Concurrent.Chan
import Control.Concurrent.Timer
import Control.Concurrent.Suspend.Lifted
import Control.Concurrent (forkIO, threadDelay, myThreadId)
import Control.Monad (forever, when)
import Thrift
import Thrift.Server
import Network
import Network.HostName
import System.Random
import System.Timeout
import RaftNodeService_Iface
import RaftNodeService
import qualified RaftNodeService_Client as Client
import qualified Rafths_Types as T

import RaftState
import RaftLog
import KeyValueApi
import ThriftClient
import ThriftTypeConverter

data NodeHand = NodeHand { state :: MVar State, chan :: Chan Event, timer :: TimerIO, peers :: [Peer] }

-- RPC Handlers
instance RaftNodeService_Iface NodeHand where
  requestVote = requestVoteHandler
  appendEntries = appendEntriesHandler

instance KeyValueStore NodeHand where
  get h k = fmap getProps (getState h) >>= lookup
    where
      store p = materialize (log p) (commitIndex p)
      lookup p = pure $ M.lookup k (store p)

  put h k v = getState h >>= update
    where
      update (Leader p n m) = do
        setState h (Leader p { log = appendLocal (log p) (k, v) (currentTerm p) } n m)
        -- TODO fire rpc to reps
      update _ = pure ()

  isLeader h = fmap leads (getState h)
    where 
      leads (Leader _ _ _) = True
      leads _ = False
  
  getLeader h = fmap leader' (getState h)
    where 
      leader' (Leader p _ _) = Just $ tupled $ self p
      leader' (Follower p) = tupledMaybe p
      leader' (Candidate p) = tupledMaybe p
      tupled p = (host p, port p)
      tupledMaybe p = fmap (tupled . read) (leader p)

newNodeHandler :: PortNumber -> [Peer] -> IO NodeHand
newNodeHandler port peers = do
  host <- getHostName
  state <- newMVar $ Follower (newProps $ Peer host (fromIntegral $ port))
  chan <- newChan :: IO (Chan Event)
  timer <- newTimer
  pure $ NodeHand state chan timer peers

getState :: NodeHand -> IO State
getState h = readMVar . state $ h

setState :: NodeHand -> State -> IO ()
setState h s = modifyMVar_ (state h) (const $ pure s)

setStateProps :: NodeHand -> State -> Props -> IO ()
setStateProps h s p = setState h $ setProps s p

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

  forkIO $ forever $ do
    threadDelay heartbeatPeriodμs
    state <- getState hand
    print $ "heartbeat thread: state = " ++ show state
    case state of (Leader p _ _) -> sendHeartbeats p peers
                  _ -> pure ()

  _ <- runServer hand RaftNodeService.process raftPort
  print "server terminated!"

data Event = ElectionTimeout -- whenever election timeout elapses without receiving heartbeat/grant vote
           | ReceivedMajorityVote -- candidate received majority, become leader
           | ReceivedAppend -- candidate contacted by leader during election, become follower
           deriving Show

handleEvent :: NodeHand -> State -> Event -> IO State
handleEvent h (Follower p) ElectionTimeout = do
  print "follower timed out! becoming candidate and starting election"
  let state = newCandidate p
  setState h state
  startElection h state
handleEvent h (Candidate p) ElectionTimeout = do
  print "timed out during election! restarting election"
  pure $ newCandidate p
handleEvent h (Leader p n m) ElectionTimeout = pure $ Leader p n m
handleEvent h (Candidate p) ReceivedAppend = pure $ Follower p
handleEvent _ s _ = pure s

requestVoteHandler :: NodeHand -> T.VoteRequest -> IO T.VoteResponse
requestVoteHandler h r = do
  print $ "RPC: requestVote() " ++ show r
  state <- getState h
  let p = getProps state
  
  when (voteRequestTerm r > currentTerm p) $ 
    setState h (Follower p { currentTerm = voteRequestTerm r })

  let grant = shouldGrantVote p r
  when grant $ do
    restartElectionTimeout h
    setStateProps h state p { votedFor = Just $ candidateId r }
  
  pure $ newVoteResponse (currentTerm p) grant

appendEntriesHandler :: NodeHand -> T.AppendRequest -> IO T.AppendResponse
appendEntriesHandler h r = do
  print $ "RPC: appendEntries() size = " ++ show (length $ entries r)
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

restartElectionTimeout :: NodeHand -> IO ()
restartElectionTimeout h = do
  timeout <- randomElectionTimeout
  print $ "restarting election timeout " ++ show timeout
  oneShotStart (timer h) (onComplete >>= const (pure ())) (usDelay timeout)
  pure ()
  where
    onComplete = forkIO $ do
      print "timeout complete! writing ElectionTimeout event"
      writeChan (chan h) ElectionTimeout

heartbeatPeriodμs = 5 * 10^6 -- 5s

sendHeartbeats :: Props -> [Peer] -> IO ()
sendHeartbeats p peers = do
  clients <- mapM newTClient (filter (/= self p) peers)
  mapM_ (forkIO . heartbeat) (catMaybes clients)
  where
    req = newHeartbeat (currentTerm p) (show $ self p) (commitIndex p)
    heartbeat c = do
      response <- Client.appendEntries c req
      pure ()

startElection :: NodeHand -> State -> IO State
startElection h (Candidate p) = do
  print "starting election"

  t <- fmap fromIntegral randomElectionTimeout
  res <- timeout t poll
  
  print $ "election result = " ++ show res
  case res of Just True -> pure $ Leader p [] []  -- todo init these arrays properly
              _ -> startElection h $ newCandidate p -- timed out, new election
  where
    poll :: IO Bool
    poll = do
      elect <- newEmptyMVar
      voteCount <- newCounter 1
      mapM_ (forkIO . getVote voteCount elect) (filter (/= self p) (peers h))
      takeMVar elect

    getVote :: AtomicCounter -> MVar Bool -> Peer -> IO ()
    getVote count elect peer = do
      vote <- requestVoteFromPeer p peer -- todo: timeout
      case vote of 
        Just v -> do
          print $ "got requestVote response! " ++ show v
          votes <- if T.voteResponse_granted v then incrCounter 1 count else readCounter count
          when (votes >= majority (peers h)) (putMVar elect True)
        _ -> pure ()

shouldGrantVote :: Props -> T.VoteRequest -> Bool
shouldGrantVote p r = 
  if currentTerm p > voteRequestTerm r then False
  else if currentTerm p < voteRequestTerm r then True
  else currentTerm p == voteRequestTerm r && 
       requestLastLogTerm r >= (fromIntegral $ lastTerm $ log p) && 
       requestLastLogIndex r >= (fromIntegral $ lastIndex $ log p) && 
       maybe True (== candidateId r) (votedFor p)

requestVoteFromPeer :: Props -> Peer -> IO (Maybe T.VoteResponse)
requestVoteFromPeer p peer = do
  print $ "creating client to " ++ show peer
  client <- newTClient peer
  let lastLogIndex = lastIndex $ log p
  let lastLogTerm = lastTerm $ log p
  let req = newVoteRequest (show $ self p) (currentTerm p) lastLogTerm lastLogIndex
  print $ "sending request " ++ show req
  case client of
    Just c -> fmap Just (Client.requestVote c req)
    _ -> pure Nothing

randomElectionTimeout :: IO Int64
randomElectionTimeout = randomRIO (t, 2 * t)
  where t = (5 * 10^6) -- 5s

