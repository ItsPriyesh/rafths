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
import qualified Data.Map as M
import qualified Data.Vector as V
import Control.Concurrent.MVar
import Control.Concurrent.Chan
import Control.Concurrent.Timer
import Control.Concurrent.Suspend.Lifted
import Control.Concurrent (forkIO, threadDelay, myThreadId)
import Control.Monad (forever)
import Thrift
import Thrift.Server
import Thrift.Protocol
import Thrift.Protocol.Binary
import Thrift.Transport
import Thrift.Transport.Handle
import Thrift.Transport.Framed
import Network
import Network.HostName
import System.IO
import System.Random
import System.Timeout
import RaftNodeService_Iface
import RaftNodeService
import qualified RaftNodeService_Client as Client
import qualified Rafths_Types as T

import RaftLog
import KeyValueApi
import ThriftTypeConverter

data Peer = Peer { host :: String, port :: Int } deriving (Eq, Show, Read, Generic)

data NodeHand = NodeHand { peers :: [Peer], state :: MVar State, chan :: Chan Event, timer :: TimerIO }

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
  currentTerm :: Int,
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
  oneShotStart (timer h) (onComplete >>= const (pure ())) (usDelay timeout)
  pure ()
  where
    onComplete = forkIO $ do
      print "timeout complete! writing ElectionTimeout event"
      writeChan (chan h) ElectionTimeout

heartbeatPeriodμs = 5 * 10^6 -- 5s
clientConnectionTimeoutμs = 2 * 10^5 -- 200ms

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
    clients <- mapM (\a -> newThriftClient (host a) (port a)) (filter (/= self p) peers) -- uncurry?
    print $ "made clients: "
    mapM_ (forkIO . heartbeat) (catMaybes clients)
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

type ThriftP = BinaryProtocol (FramedTransport Handle)
type ThriftC = (ThriftP, ThriftP)

newThriftClient :: String -> Int -> IO (Maybe ThriftC)
newThriftClient host port = do
  print "hopening" -- TODO: failure during connection causes this thread to hang (timout not working)
  transport <- timeout clientConnectionTimeoutμs (hOpen (host, PortNumber . fromIntegral $ port))
  print "hopened"
  case transport of
    Just t -> fmap (\p -> Just (p, p)) (frame t)
    Nothing -> pure Nothing
  where
    frame t = fmap BinaryProtocol (openFramedTransport t)

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
  print $ "RPC: requestVote() " ++ show r
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
  else if currentTerm p < voteRequestTerm r then True
  else currentTerm p == voteRequestTerm r && 
       requestLastLogTerm r >= (fromIntegral $ lastTerm $ log p) && 
       requestLastLogIndex r >= (fromIntegral $ lastIndex $ log p) && 
       maybe True (== candidateId r) (votedFor p)

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
    
handleEvent :: NodeHand -> State -> Event -> IO State
handleEvent h (Follower p) ElectionTimeout = do
  print "follower timed out! becoming candidate and starting election"
  let state = newCandidate p
  setState h state
  requestVotes h state
handleEvent h (Candidate p) ElectionTimeout = do
  print "timed out during election! restarting election"
  pure $ newCandidate p
handleEvent h (Leader p n m) ElectionTimeout = pure $ Leader p n m
handleEvent h (Candidate p) ReceivedAppend = pure $ Follower p
handleEvent _ s _ = pure s

-- Increments term and becomes Candidate
newCandidate :: Props -> State
newCandidate p = Candidate p { currentTerm = 1 + currentTerm p}

requestVotes :: NodeHand -> State -> IO State
requestVotes h (Candidate p) = do
  print "starting election"

  t <- fmap fromIntegral randomElectionTimeout
  res <- timeout t startElection
  
  print $ "election result = " ++ show res
  case res of Just True -> pure $ Leader p [] []
              _ -> requestVotes h (Candidate p) -- timed out
  where
    startElection :: IO Bool
    startElection = do
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
          if votes >= majority (peers h) then putMVar elect True else pure ()
        _ -> pure ()

    electionResult ElectionTimeout = requestVotes h (Candidate p) -- stay in same state, start new election
    electionResult ReceivedMajorityVote = pure $ Leader p [] [] -- todo init these arrays properly
    electionResult ReceivedAppend = pure $ Follower p

requestVoteFromPeer :: Props -> Peer -> IO (Maybe T.VoteResponse)
requestVoteFromPeer p peer = do
  print $ "creating client to " ++ show peer
  client <- newThriftClient (host peer) (port peer)
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

majority :: [Peer] -> Int
majority peers = if even n then 1 + quot n 2 else quot (n + 1) 2
  where n = length $ peers
