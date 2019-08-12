{-# LANGUAGE DeriveGeneric #-}

module RaftState where

import RaftLog
import GHC.Generics (Generic)
import Prelude hiding (log)
import qualified Data.Map as M

data State = Follower  Props 
           | Candidate Props 
           | Leader    Props (M.Map Peer PeerMeta)
           deriving Show

data Peer = Peer { host :: String,  port :: Int } deriving (Eq, Show, Read, Generic, Ord)

data PeerMeta = PeerMeta { nextIndex :: Int, matchIndex :: Int } deriving Show

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

majority :: [Peer] -> Int
majority peers = if even n then 1 + quot n 2 else quot (n + 1) 2
  where n = length peers + 1

toFollower :: State -> State
toFollower (Follower p) = Follower p
toFollower (Candidate p) = Follower p
toFollower (Leader p _) = Follower p

newLeader :: Props -> [Peer] -> State
newLeader p peers = Leader p $ M.fromList $ map newMeta peers
  where newMeta peer = (peer, PeerMeta (lastIndex $ log p) 0)

newCandidate :: Props -> State
newCandidate p = Candidate p { currentTerm = 1 + currentTerm p}

getProps :: State -> Props
getProps (Follower p) = p
getProps (Candidate p) = p
getProps (Leader p _) = p

setProps :: State -> Props -> State
setProps (Follower _) p  = Follower p
setProps (Candidate _) p = Candidate p
setProps (Leader _ n) p =  Leader p n
