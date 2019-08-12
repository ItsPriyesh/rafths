module Main where

import System.Environment   

import RaftNode
import RaftState

main :: IO ()
main = do
  args <- getArgs
  let port = read $ args !! 0
  let rpcPort = read $ args !! 1
  RaftNode.serve port rpcPort [Peer "Priyeshs-MacBook-Pro.local" 8022, Peer "Priyeshs-MacBook-Pro.local" 8023]