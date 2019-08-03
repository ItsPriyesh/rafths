module RaftNode where

import Control.Concurrent.MVar

import ClusterNode_Iface
import qualified Rafths_Types as T

instance ClusterNode_Iface NodeHandler where
  requestVote = handleRequestVote
  appendEntries = handleAppendEntries

data LogEntry = LogEntry { key :: String , value :: String } deriving (Show)

newtype NodeHandler = NodeHandler { getLog :: MVar [LogEntry] }

newNodeHandler :: IO NodeHandler
newNodeHandler = do
  log <- newMVar mempty
  pure $ NodeHandler log

handleRequestVote :: NodeHandler -> T.VoteRequest -> IO T.VoteResponse
handleRequestVote handler request = do
  pure T.VoteResponse { T.voteResponse_term = 1, T.voteResponse_granted = True }

handleAppendEntries :: NodeHandler -> T.AppendRequest -> IO T.AppendResponse
handleAppendEntries handler request = do
  pure T.AppendResponse { T.appendResponse_term = 1, T.appendResponse_success = True }
