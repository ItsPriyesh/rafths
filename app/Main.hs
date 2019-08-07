module Main where

import System.Environment   

import RaftNode

main :: IO ()
main = do
  args <- getArgs
  let port = read $ args !! 0
  RaftNode.serve port [Peer "Priyeshs-MacBook-Pro.local" 8011, Peer "Priyeshs-MacBook-Pro.local" 8012]