module ThriftClient where

import RaftState
import Network
import System.IO
import System.Timeout
import Thrift.Protocol
import Thrift.Protocol.Binary
import Thrift.Transport
import Thrift.Transport.Handle
import Thrift.Transport.Framed

type TProto = BinaryProtocol (FramedTransport Handle)
type TClient = (TProto, TProto)

newTClient :: Peer -> IO (Maybe TClient)
newTClient (Peer host port) = do
  print "hopening" -- TODO: failure during connection causes the thread to hang (timout not working)
  transport <- timeout clientConnectionTimeoutμs (hOpen (host, PortNumber . fromIntegral $ port))
  print "hopened"
  case transport of
    Just t -> fmap (\p -> Just (p, p)) (frame t)
    Nothing -> pure Nothing
  where
    frame t = fmap BinaryProtocol (openFramedTransport t)

clientConnectionTimeoutμs = 2 * 10^5 -- 200ms
