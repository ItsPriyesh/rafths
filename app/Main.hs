module Main where

import Server
import qualified Thrift.Server as Th
import qualified ClusterNode

main :: IO ()
main =  do
  handler <- Server.newCalculatorHandler
  print "Starting the server..."
  _ <- Th.runBasicServer handler ClusterNode.process 9090
  print "closing down server"
