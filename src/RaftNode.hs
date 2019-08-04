module RaftNode where

import Control.Concurrent.MVar

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

import ClusterNode_Iface
import qualified ClusterNode_Client as Client
import qualified Rafths_Types as T

instance ClusterNode_Iface NodeHandler where
  requestVote = requestVoteHandler
  appendEntries = appendEntriesHandler

data Role = Follower State | Candidate State | Leader State [Int] [Int]

getRaftState :: Role -> State
getRaftState (Follower s) = s
getRaftState (Candidate s) = s
getRaftState (Leader s _ _) = s

-- fold over [LogEntry] to get current state of kv store
data State = State {
  currentTerm :: Int64,
  votedFor :: Maybe Int32,
  logEntries :: [LogEntry],
  commitIndex :: Int32,
  lastApplied :: Int32
}

emptyState :: State
emptyState = State 0 Nothing [] 0 0

data LogEntry = LogEntry { key :: String , value :: String }

data ServerState = ServerState { role :: Role, peers :: [(String, Int)] }

newtype NodeHandler = NodeHandler { serverState :: MVar ServerState }

newNodeHandler :: [(String, Int)] -> IO NodeHandler
newNodeHandler peers = do
  state <- newMVar (ServerState (Follower emptyState) peers)
  pure $ NodeHandler state

getServerState :: NodeHandler -> IO ServerState
getServerState = readMVar . serverState

-- RPC Handlers
requestVoteHandler :: NodeHandler -> T.VoteRequest -> IO T.VoteResponse
requestVoteHandler handler request = do
  print "request vote called!"
  serverState <- getServerState handler
  let state = getRaftState $ role $ serverState
  pure $ newVoteResponse (currentTerm state) (shouldGrant state request)

newVoteResponse :: Int64 -> Bool -> T.VoteResponse
newVoteResponse term grant = T.VoteResponse { T.voteResponse_term = term, T.voteResponse_granted = grant }

shouldGrant :: State -> T.VoteRequest -> Bool
shouldGrant state req = if currentTerm state > T.voteRequest_term req then False else grant
  where
    voted = maybe True (== T.voteRequest_candidateId req) (votedFor state)
    upToDate = (length $ logEntries $ state) - 1 <= (fromIntegral $ T.voteRequest_lastLogIndex req)
    grant = voted && upToDate

appendEntriesHandler :: NodeHandler -> T.AppendRequest -> IO T.AppendResponse
appendEntriesHandler handler request = do
  pure T.AppendResponse { T.appendResponse_term = 1, T.appendResponse_success = True }

-- Creates a client RPC stub referencing another node in the cluster
newThriftClient :: String -> Integer -> IO (BinaryProtocol Handle, BinaryProtocol Handle)
newThriftClient host port = do
  transport <- hOpen (host, (PortNumber . fromInteger $ port))
  let proto = BinaryProtocol transport
  pure (proto, proto)
