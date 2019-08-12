{-# LANGUAGE DeriveGeneric #-}

module RaftState where

import GHC.Generics (Generic)
import RaftLog

data State = Follower  Props 
           | Candidate Props 
           | Leader    Props [Int] [Int]
           deriving Show

data Peer = Peer { 
  host :: String, 
  port :: Int,
  nextIndex :: Int,
  matchIndex :: Int
} deriving (Eq, Show, Read, Generic)

newPeer :: String -> Int -> Peer
newPeer h p = Peer h p 0 0

majority :: [Peer] -> Int
majority peers = if even n then 1 + quot n 2 else quot (n + 1) 2
  where n = length peers + 1

data Props = Props {
  self :: Peer,
  log :: Log,
  currentTerm :: Int,
  leader :: Maybe String,
  votedFor :: Maybe String,
  commitIndex :: Int,
  lastApplied :: Int
} deriving Show

newProps :: Peer -> Props
newProps self = Props self [] 0 Nothing Nothing 0 0

-- nextIndex (Leader _ n _) = n
-- matchIndex (Leader _ _ n) = n

toFollower :: State -> State
toFollower (Follower p) = Follower p
toFollower (Candidate p) = Follower p
toFollower (Leader p _ _) = Follower p

newCandidate :: Props -> State
newCandidate p = Candidate p { currentTerm = 1 + currentTerm p}

getProps :: State -> Props
getProps (Follower p) = p
getProps (Candidate p) = p
getProps (Leader p _ _) = p

setProps :: State -> Props -> State
setProps (Follower _) p  = Follower p
setProps (Candidate _) p = Candidate p
setProps (Leader _ n m) p =  Leader p n m
