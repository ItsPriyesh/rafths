module ThriftConverter where

import Data.Int

import qualified Rafths_Types as T

newVoteRequest :: Int -> Int64 -> Int -> Int -> T.VoteRequest
newVoteRequest candidate term lastLogTerm lastLogIndex = T.VoteRequest { 
  T.voteRequest_candidateId = fromIntegral $ candidate,
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

