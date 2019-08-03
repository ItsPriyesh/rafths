module Main where

import RaftNode
import qualified Thrift.Server as Th
import qualified ClusterNode

main :: IO ()
main =  do
  handler <- RaftNode.newNodeHandler
  print "Starting the server..."
  _ <- Th.runBasicServer handler ClusterNode.process 9090
  print "closing down server"
