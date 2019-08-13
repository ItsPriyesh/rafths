{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module KeyValueApi where

import qualified Web.Scotty as S
import Control.Monad
import Control.Monad.Trans
import Network
import Data.Text.Lazy

class KeyValueStore s where
  isLeader :: s -> IO Bool
  getLeader :: s -> IO (Maybe (String, Int))
  get :: s -> String -> IO (Maybe String)
  put :: s -> String -> String -> IO Bool

-- GET /:key   - returns the value for the specified key or null if it doesnt exist
-- POST /:key  - sets a value for the specified key, returns a flag indicating 
--               whether or not the update was committed to the Raft cluster 

serve :: KeyValueStore s => PortNumber -> s -> IO ()
serve port s = S.scotty (fromIntegral $ port) $ do
  S.get "/:key" $ do
    k <- S.param "key"
    res <- liftIO $ onLeader s k $ fmap show $ get s k
    handle res

  S.post "/:key" $ do
    k <- S.param "key"
    v <- S.param "value"
    res <- liftIO $ onLeader s k $ fmap show $ put s k v
    handle res

  where 
    handle r = case r of
      Success s -> respond s
      Redirect t -> S.redirect t
      Unavailable -> S.raise "Leader currently unavailable!"

data Response = Success String | Redirect Text | Unavailable

onLeader :: KeyValueStore s => s -> String -> IO String -> IO Response
onLeader s k op = do
  leads <- isLeader s
  if leads then
    fmap Success $ liftIO $ op
  else do
    leader <- getLeader s
    pure $ case leader of
      Just (h, p) -> Redirect $ leaderLocation h p k
      _ -> Unavailable

leaderLocation :: String -> Int -> String -> Text
leaderLocation host port k = pack $ "http://" ++ host ++ ":" ++ show port ++ "/" ++ k

respond :: Show a => a -> S.ActionM ()
respond s = S.text $ pack $ show s
