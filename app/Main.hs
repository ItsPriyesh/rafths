{-# LANGUAGE DeriveGeneric #-}

module Main where

import RaftNode
import RaftState

import Network
import System.Environment   
import GHC.Generics
import qualified Data.Yaml as YAML

data ClusterConfig = ClusterConfig { nodes :: [Peer] } deriving (Generic, Show)

instance YAML.FromJSON ClusterConfig

main :: IO ()
main = do
  args <- getArgs
  let apiPort = read $ args !! 0 :: PortNumber
  let rpcPort = read $ args !! 1 :: PortNumber

  config <- YAML.decodeFile "cluster.yaml" :: IO (Maybe ClusterConfig)
  
  case config of
    Just (ClusterConfig peers) -> RaftNode.serve apiPort rpcPort peers
    _ -> print "Invalid cluster config!"
