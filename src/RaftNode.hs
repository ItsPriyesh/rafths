{-# LANGUAGE OverloadedStrings #-}

module RaftNode where

import Control.Concurrent.MVar

import ClusterNode_Iface
import Rafths_Types

instance ClusterNode_Iface NodeHandler where
  requestVote = handleRequestVote
  appendEntries = handleAppendEntries

data LogEntry = LogEntry { key :: String , value :: String } deriving (Show)

newtype NodeHandler = NodeHandler { getLog :: MVar [LogEntry] }

newNodeHandler :: IO NodeHandler
newNodeHandler = do
  log <- newMVar mempty
  pure $ NodeHandler log

handleRequestVote :: NodeHandler -> VoteRequest -> IO VoteResponse
handleRequestVote handler request = do
  pure VoteResponse { voteResponse_term = 1, voteResponse_granted = true }

handleAppendEntries :: NodeHandler -> AppendRequest -> IO AppendResponse
handleRequestVote handler request = do
  pure AppendResponse { appendResponse_term = 1, appendResponse_success = true }
  