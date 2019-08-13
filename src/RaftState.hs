{-# LANGUAGE DeriveGeneric #-}

module RaftState where

import RaftLog
import GHC.Generics (Generic)
import Prelude hiding (log)
import qualified Data.Map as M

data State = Follower  Props 
           | Candidate Props 
           | Leader    Props PeerMetadata
           deriving Show

data Peer = Peer { host :: String,  port :: Int } deriving (Eq, Show, Read, Generic, Ord)

data PeerMeta = PeerMeta { nextIndex :: Int, matchIndex :: Int } deriving Show

type PeerMetadata = M.Map Peer PeerMeta

data Props = Props {
  self        :: Peer,
  log         :: Log,
  currentTerm :: Int,
  leader      :: Maybe String,
  votedFor    :: Maybe String,
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

nextIndexForPeer :: PeerMetadata -> Peer -> Int
nextIndexForPeer meta peer = maybe 0 nextIndex $ M.lookup peer meta

matchIndexForPeer :: PeerMetadata -> Peer -> Int
matchIndexForPeer meta peer = maybe 0 matchIndex $ M.lookup peer meta

updateMetadataForPeer :: PeerMetadata -> Peer -> Int -> PeerMetadata
updateMetadataForPeer meta peer lastLogIndex = M.insert peer m meta
  where m = PeerMeta (lastLogIndex + 1) lastLogIndex

decrementIndexForPeer :: PeerMetadata -> Peer -> PeerMetadata
decrementIndexForPeer meta peer = M.adjust decr peer meta
  where decr (PeerMeta n m) = if n > 0 then PeerMeta (n - 1) m else PeerMeta n m

appendLocally :: State -> (String, String) -> State
appendLocally (Leader p meta) (k, v) = Leader p { 
    log = appendUncommitted (log p) (k, v) (currentTerm p) 
  } meta

commitLatest :: State -> State
commitLatest (Leader p meta) = Leader p { commitIndex = lastIndex $ log p } meta

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
