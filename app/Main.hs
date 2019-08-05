module Main where

import RaftNode

main = RaftNode.start 8080 [Peer "localhost" 8080]