module Main where

import RaftNode

main = RaftNode.start 10123 [Peer "localhost" 10123]