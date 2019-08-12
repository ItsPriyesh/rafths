{-# LANGUAGE ScopedTypeVariables #-}

module ThriftClient where

import RaftState
import Network
import System.IO
import System.Timeout
import Control.Exception

import Thrift.Protocol
import Thrift.Protocol.Binary
import Thrift.Transport
import Thrift.Transport.Handle
import Thrift.Transport.Framed

type TProto = BinaryProtocol (FramedTransport Handle)
type TClient = (TProto, TProto)

newTClient :: Peer -> IO (Maybe TClient)
newTClient peer = do
  transport <- connect peer
  case transport of
    Just t -> fmap (\p -> Just (p, p)) (frame t)
    Nothing -> pure Nothing
  where
    frame t = fmap BinaryProtocol (openFramedTransport t)

connect :: Peer -> IO (Maybe Handle)
connect (Peer h p _ _) = catch (fmap Just open) (\(e :: SomeException) -> pure Nothing)
  where open = hOpen (h, PortNumber . fromIntegral $ p)
