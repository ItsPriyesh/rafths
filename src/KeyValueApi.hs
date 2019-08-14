{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module KeyValueApi (
  serve, 
  KeyValueStore, get, put, isLeader, getLeader
) where

import RaftState
import Control.Monad
import Control.Monad.Trans
import Control.Lens
import Network
import Network.Wreq (post, responseBody, FormParam((:=)))
import qualified Web.Scotty as S
import Data.Text.Lazy

class KeyValueStore s where
  get :: s -> String -> IO (Maybe String)
  put :: s -> String -> String -> IO Bool
  isLeader :: s -> IO Bool
  getLeader :: s -> IO (Maybe Peer)

--
-- GET  /:key            returns the value for the specified key or null if it doesnt exist
-- POST /:key?value='v'  sets a value for the specified key, returns a flag indicating 
--                       whether or not the update was committed to the Raft cluster 
--
serve :: KeyValueStore s => PortNumber -> s -> IO ()
serve port s = S.scotty (fromIntegral $ port) $ do
  S.get "/:key" $ do
    k <- S.param "key"
    res <- liftIO $ onLeader s k $ fmap fmtMaybe $ get s k
    case res of
      Success r -> respond r
      Redirect leader -> S.redirect leader
      Unavailable -> S.raise "Leader unavailable!"
  S.post "/:key" $ do
    k <- S.param "key"
    v <- S.param "value"
    res <- liftIO $ onLeader s k $ fmap show $ put s k v
    case res of
      Success r -> respond r
      Redirect l -> (liftIO $ fmap (^. responseBody) $ forwardPost l v) >>= respond
      Unavailable -> S.raise "Leader unavailable!"
  where
    forwardPost leader v = post (unpack leader) ["value" := v]

data Response = Success String | Redirect Text | Unavailable

onLeader :: KeyValueStore s => s -> String -> IO String -> IO Response
onLeader s k op = do
  leads <- isLeader s
  if leads then
    fmap Success $ liftIO $ op
  else do
    leader <- getLeader s
    pure $ case leader of
      Just (Peer h _ p) -> Redirect $ leaderLocation h p k
      _ -> Unavailable

leaderLocation :: String -> Int -> String -> Text
leaderLocation host port k = pack $ "http://" ++ host ++ ":" ++ show port ++ "/" ++ k

respond :: Show a => a -> S.ActionM ()
respond s = S.text $ pack $ show s

fmtMaybe :: Show a => Maybe a -> String
fmtMaybe m = maybe "null" show m
