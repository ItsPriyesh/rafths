module RaftLog where

import Data.List
import ThriftUtil

import qualified Data.Vector as V
import qualified Rafths_Types as T

data LogEntry = LogEntry { keyValue :: (String, String), term :: Int } deriving Show

type Log = [LogEntry]

lastIndex :: Log -> Int
lastIndex l = length l - 1

lastTerm :: Log -> Int
lastTerm l = if null l then -1 else term $ l !! lastIndex l 

termMatchedAtIndex :: Log -> Int -> Int -> Bool
termMatchedAtIndex l t i = 
  if null l || i > lastIndex l then False
  else term (l !! i) == t

termConflictAtIndex :: Log -> Int -> Int -> Bool
termConflictAtIndex l t i = 
  if null l || i > lastIndex l then False
  else term (l !! i) /= t

append :: Log -> Int -> V.Vector T.LogEntry -> Log
append l startIndex entries = 
  if null right then left ++ entriesL -- disjoint, simple append
  else case conflictingIndex of
    Just i -> (take i l) ++ entriesL -- conflicting term, replace local with leader entries
    Nothing -> left ++ entriesL -- no conflicts, simple append
  where
    (left, right) = splitAt startIndex l

    conflict (e, i) = termConflictAtIndex l (term e) i
    conflictingIndex = findIndex conflict (zip entriesL [startIndex..])    
    
    newEntry e = LogEntry (entryTuple e) (entryTerm e)
    entriesL = map newEntry (V.toList entries)