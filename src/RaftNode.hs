module RaftNode where

import Control.Concurrent.MVar

import Thrift
import Thrift.Protocol
import Thrift.Protocol.Binary
import Thrift.Transport
import Thrift.Transport.Handle
import Thrift.Server
import Network

import System.IO

import ClusterNode_Iface
import qualified ClusterNode_Client as Client
import qualified Rafths_Types as T

instance ClusterNode_Iface NodeHandler where
  requestVote = handleRequestVote
  appendEntries = handleAppendEntries

data Role = Follower State | Candidate State | Leader State

-- fold over [LogEntry] to get current state of kv store
data State = State {
  currentTerm :: Int,
  votedFor :: Maybe Int,
  log :: [LogEntry],
  commitIndex :: Int,
  lastApplied :: Int
}

emptyState :: State
emptyState = State 0 Nothing [] 0 0

data LogEntry = LogEntry { key :: String , value :: String }

data ServerState = ServerState { role :: Role, peers :: [(String, Int)] }

newtype NodeHandler = NodeHandler { serverState :: MVar ServerState }

newNodeHandler :: [(String, Int)] -> IO NodeHandler
newNodeHandler peers = do
  newServerSate <- newMVar (ServerState (Follower emptyState) peers)
  pure $ NodeHandler newServerSate

-- RPC Handlers
handleRequestVote :: NodeHandler -> T.VoteRequest -> IO T.VoteResponse
handleRequestVote handler request = do
  print "request vote called!"
  pure T.VoteResponse { T.voteResponse_term = 1, T.voteResponse_granted = True }

handleAppendEntries :: NodeHandler -> T.AppendRequest -> IO T.AppendResponse
handleAppendEntries handler request = do
  pure T.AppendResponse { T.appendResponse_term = 1, T.appendResponse_success = True }

-- Creates a client RPC stub referencing another node in the cluster
newThriftClient :: String -> Integer -> IO (BinaryProtocol Handle, BinaryProtocol Handle)
newThriftClient host port = do
  transport <- hOpen (host, (PortNumber . fromInteger $ port))
  let proto = BinaryProtocol transport
  pure (proto, proto)
