{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -fno-warn-missing-fields #-}
{-# OPTIONS_GHC -fno-warn-missing-signatures #-}
{-# OPTIONS_GHC -fno-warn-name-shadowing #-}
{-# OPTIONS_GHC -fno-warn-unused-imports #-}
{-# OPTIONS_GHC -fno-warn-unused-matches #-}

-----------------------------------------------------------------
-- Autogenerated by Thrift Compiler (0.12.0)                      --
--                                                             --
-- DO NOT EDIT UNLESS YOU ARE SURE YOU KNOW WHAT YOU ARE DOING --
-----------------------------------------------------------------

module RaftNodeService_Client(requestVote,appendEntries) where
import qualified Data.IORef as R
import Prelude (($), (.), (>>=), (==), (++))
import qualified Prelude as P
import qualified Control.Exception as X
import qualified Control.Monad as M ( liftM, ap, when )
import Data.Functor ( (<$>) )
import qualified Data.ByteString.Lazy as LBS
import qualified Data.Hashable as H
import qualified Data.Int as I
import qualified Data.Maybe as M (catMaybes)
import qualified Data.Text.Lazy.Encoding as E ( decodeUtf8, encodeUtf8 )
import qualified Data.Text.Lazy as LT
import qualified GHC.Generics as G (Generic)
import qualified Data.Typeable as TY ( Typeable )
import qualified Data.HashMap.Strict as Map
import qualified Data.HashSet as Set
import qualified Data.Vector as Vector
import qualified Test.QuickCheck.Arbitrary as QC ( Arbitrary(..) )
import qualified Test.QuickCheck as QC ( elements )

import qualified Thrift as T
import qualified Thrift.Types as T
import qualified Thrift.Arbitraries as T


import Rafths_Types
import RaftNodeService
seqid = R.newIORef 0
requestVote (ip,op) arg_req = do
  send_requestVote op arg_req
  recv_requestVote ip
send_requestVote op arg_req = do
  seq <- seqid
  seqn <- R.readIORef seq
  T.writeMessage op ("requestVote", T.M_CALL, seqn) $
    write_RequestVote_args op (RequestVote_args{requestVote_args_req=arg_req})
recv_requestVote ip = do
  T.readMessage ip $ \(fname, mtype, rseqid) -> do
    M.when (mtype == T.M_EXCEPTION) $ do { exn <- T.readAppExn ip ; X.throw exn }
    res <- read_RequestVote_result ip
    P.return $ requestVote_result_success res
appendEntries (ip,op) arg_req = do
  send_appendEntries op arg_req
  recv_appendEntries ip
send_appendEntries op arg_req = do
  seq <- seqid
  seqn <- R.readIORef seq
  T.writeMessage op ("appendEntries", T.M_CALL, seqn) $
    write_AppendEntries_args op (AppendEntries_args{appendEntries_args_req=arg_req})
recv_appendEntries ip = do
  T.readMessage ip $ \(fname, mtype, rseqid) -> do
    M.when (mtype == T.M_EXCEPTION) $ do { exn <- T.readAppExn ip ; X.throw exn }
    res <- read_AppendEntries_result ip
    P.return $ appendEntries_result_success res