module Main where

import RaftNode
import qualified Thrift.Server as T
import qualified ClusterNode
import qualified ClusterNode_Client as Client
import qualified Rafths_Types as T

main :: IO ()
main = do
  handler <- RaftNode.newNodeHandler [("localhost", 8080)]
  print "Starting server..."
  client <- RaftNode.newThriftClient "localhost" 8080
  response <- Client.requestVote client T.VoteRequest { T.voteRequest_candidateId = 0 , T.voteRequest_term = 0, T.voteRequest_lastLogTerm = 0, T.voteRequest_lastLogIndex = 0 }
  print response
  -- _ <- T.runBasicServer handler ClusterNode.process 8080 -- todo runThreadedServer
  print "Server terminated!"
