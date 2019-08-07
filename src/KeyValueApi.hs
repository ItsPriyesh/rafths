{-# LANGUAGE DeriveGeneric     #-}
{-# LANGUAGE OverloadedStrings #-}

module KeyValueApi where

import Network

class KeyValueStore s where
  isLeader :: s -> IO Bool
  getLeader :: s -> IO (String, Int)
  get :: s -> String -> IO (Maybe String)
  put :: s -> String -> String -> IO ()

-- An HTTP API to access the key value store
-- GET /:key   - returns the value for the key or null if it doesnt exist
-- POST /:key  - sets a value for the specified key

serveHttpApi :: KeyValueStore kv => PortNumber -> kv -> IO ()
serveHttpApi port kv = pure ()