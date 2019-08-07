module ThriftUtil where

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

newThriftClient :: String -> Int -> IO (BinaryProtocol (FramedTransport Handle), BinaryProtocol (FramedTransport Handle))
newThriftClient host port = do
  print "opening"
  transport <- hOpen (host, PortNumber . fromIntegral $ port)
  print "opened"
  framed <- openFramedTransport transport
  let proto = BinaryProtocol framed
  pure (proto, proto)

newVoteRequest :: Int -> Int64 -> Int -> Int -> T.VoteRequest
newVoteRequest candidate term lastLogTerm lastLogIndex = T.VoteRequest { 
  T.voteRequest_candidateId = fromIntegral candidate,
  T.voteRequest_term = term,
  T.voteRequest_lastLogTerm = fromIntegral lastLogTerm,
  T.voteRequest_lastLogIndex = fromIntegral lastLogIndex
}

newVoteResponse :: Int64 -> Bool -> T.VoteResponse
newVoteResponse term grant = T.VoteResponse { 
  T.voteResponse_term = term, 
  T.voteResponse_granted = grant
}

newAppendResponse :: Int64 -> Bool -> T.AppendResponse
newAppendResponse term success = T.AppendResponse { 
  T.appendResponse_term = term, 
  T.appendResponse_success = success 
}

newHeartbeat :: Int64 -> Int -> Int32 -> T.AppendRequest
newHeartbeat term leader leaderCommitIndex = T.AppendRequest { 
  T.appendRequest_term = term,
  T.appendRequest_leaderId = fromIntegral leader,
  T.appendRequest_prevLogIndex = -1,
  T.appendRequest_prevLogTerm = -1,
  T.appendRequest_leaderCommitIndex = leaderCommitIndex,
  T.appendRequest_entries = V.empty :: V.Vector T.LogEntry
}

newLogEntry :: String -> String -> Int64 -> T.LogEntry
newLogEntry key value term = T.LogEntry {
  T.logEntry_command = pack $ show key ++ "," ++ show value, -- handle delimiter issues
  T.logEntry_term = term
}

