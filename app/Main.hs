module Main where

import System.Environment   

import RaftNode
import RaftState

main :: IO ()
main = do
  args <- getArgs
  let port = read $ args !! 0
  let raftPort = read $ args !! 1
  RaftNode.serve port raftPort [newPeer "Priyeshs-MacBook-Pro.local" 8022, newPeer "Priyeshs-MacBook-Pro.local" 8023]