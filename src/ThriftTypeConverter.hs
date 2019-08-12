module ThriftTypeConverter where

import Data.Int
import Data.Text.Lazy
import qualified Data.Vector as V

import Thrift
import Thrift.Server
import Thrift.Protocol
import Thrift.Protocol.Binary
import Thrift.Transport
import Thrift.Transport.Handle
import Thrift.Transport.Framed

import System.IO
import Network

import qualified Rafths_Types as T

-- Framed transport used to support threaded server
runServer :: h 
          -> (h -> (BinaryProtocol (FramedTransport Handle), BinaryProtocol (FramedTransport Handle)) -> IO Bool) 
          -> PortNumber
          -> IO a
runServer h proc port = runThreadedServer acceptor h proc (PortNumber $ fromIntegral port)
  where
    acceptor sock = do
      (h, _, _) <- (accept sock)
      t <- openFramedTransport h
      return (BinaryProtocol t, BinaryProtocol t)


newVoteRequest :: String -> Int -> Int -> Int -> T.VoteRequest
newVoteRequest candidate term lastLogTerm lastLogIndex = T.VoteRequest { 
  T.voteRequest_candidateId = pack candidate,
  T.voteRequest_term = fromIntegral $ term,
  T.voteRequest_lastLogTerm = fromIntegral lastLogTerm,
  T.voteRequest_lastLogIndex = fromIntegral lastLogIndex
}

candidateId :: T.VoteRequest -> String
candidateId r = unpack $ T.voteRequest_candidateId r

voteRequestTerm :: T.VoteRequest -> Int
voteRequestTerm r = fromIntegral $ T.voteRequest_term r

requestLastLogTerm :: T.VoteRequest -> Int64
requestLastLogTerm r = T.voteRequest_lastLogTerm r

requestLastLogIndex :: T.VoteRequest -> Int32
requestLastLogIndex r = T.voteRequest_lastLogIndex r

newVoteResponse :: Int -> Bool -> T.VoteResponse
newVoteResponse term grant = T.VoteResponse { 
  T.voteResponse_term = fromIntegral $ term, 
  T.voteResponse_granted = grant
}

newAppendResponse :: Int -> Bool -> T.AppendResponse
newAppendResponse term success = T.AppendResponse { 
  T.appendResponse_term = fromIntegral term, 
  T.appendResponse_success = success 
}

appendResponseSuccess :: T.AppendResponse -> Bool
appendResponseSuccess r = T.appendResponse_success r

newHeartbeat :: Int -> String -> Int -> Int -> Int -> T.AppendRequest
newHeartbeat term leader leaderCommitIndex prevLogIndex prevLogTerm = 
  newAppendRequest term leader leaderCommitIndex prevLogIndex prevLogTerm (V.empty :: V.Vector T.LogEntry)

newAppendRequest :: Int -> String -> Int -> Int -> Int -> V.Vector T.LogEntry -> T.AppendRequest
newAppendRequest term leader leaderCommitIndex prevLogIndex prevLogTerm entries = T.AppendRequest { 
  T.appendRequest_term = fromIntegral term,
  T.appendRequest_leaderId = pack leader,
  T.appendRequest_prevLogIndex = fromIntegral prevLogIndex,
  T.appendRequest_prevLogTerm = fromIntegral prevLogTerm,
  T.appendRequest_leaderCommitIndex = fromIntegral leaderCommitIndex,
  T.appendRequest_entries = entries
}

appendRequestTerm :: T.AppendRequest -> Int
appendRequestTerm r = fromIntegral $ T.appendRequest_term r

leaderId :: T.AppendRequest -> String
leaderId r = unpack $ T.appendRequest_leaderId r

entries :: T.AppendRequest -> V.Vector T.LogEntry
entries r = T.appendRequest_entries r

prevLogTerm :: T.AppendRequest -> Int
prevLogTerm r = fromIntegral $ T.appendRequest_prevLogTerm r

prevLogIndex :: T.AppendRequest -> Int
prevLogIndex r = fromIntegral $ T.appendRequest_prevLogIndex r

leaderCommitIndex :: T.AppendRequest -> Int
leaderCommitIndex r = fromIntegral $ T.appendRequest_leaderCommitIndex r

newLogEntry :: (String, String) -> Int -> T.LogEntry
newLogEntry entry term = T.LogEntry {
  T.logEntry_command = pack $ show entry,
  T.logEntry_term = fromIntegral term
}

entryTerm :: T.LogEntry -> Int
entryTerm e = fromIntegral $ T.logEntry_term e

entryTuple :: T.LogEntry -> (String, String)
entryTuple e = read $ unpack $ T.logEntry_command e