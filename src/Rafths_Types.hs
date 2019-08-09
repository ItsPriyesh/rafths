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

module Rafths_Types where
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


data VoteRequest = VoteRequest  { voteRequest_candidateId :: LT.Text
  , voteRequest_term :: I.Int64
  , voteRequest_lastLogTerm :: I.Int64
  , voteRequest_lastLogIndex :: I.Int32
  } deriving (P.Show,P.Eq,G.Generic,TY.Typeable)
instance H.Hashable VoteRequest where
  hashWithSalt salt record = salt   `H.hashWithSalt` voteRequest_candidateId record   `H.hashWithSalt` voteRequest_term record   `H.hashWithSalt` voteRequest_lastLogTerm record   `H.hashWithSalt` voteRequest_lastLogIndex record  
instance QC.Arbitrary VoteRequest where 
  arbitrary = M.liftM VoteRequest (QC.arbitrary)
          `M.ap`(QC.arbitrary)
          `M.ap`(QC.arbitrary)
          `M.ap`(QC.arbitrary)
  shrink obj | obj == default_VoteRequest = []
             | P.otherwise = M.catMaybes
    [ if obj == default_VoteRequest{voteRequest_candidateId = voteRequest_candidateId obj} then P.Nothing else P.Just $ default_VoteRequest{voteRequest_candidateId = voteRequest_candidateId obj}
    , if obj == default_VoteRequest{voteRequest_term = voteRequest_term obj} then P.Nothing else P.Just $ default_VoteRequest{voteRequest_term = voteRequest_term obj}
    , if obj == default_VoteRequest{voteRequest_lastLogTerm = voteRequest_lastLogTerm obj} then P.Nothing else P.Just $ default_VoteRequest{voteRequest_lastLogTerm = voteRequest_lastLogTerm obj}
    , if obj == default_VoteRequest{voteRequest_lastLogIndex = voteRequest_lastLogIndex obj} then P.Nothing else P.Just $ default_VoteRequest{voteRequest_lastLogIndex = voteRequest_lastLogIndex obj}
    ]
from_VoteRequest :: VoteRequest -> T.ThriftVal
from_VoteRequest record = T.TStruct $ Map.fromList $ M.catMaybes
  [ (\_v2 -> P.Just (1, ("candidateId",T.TString $ E.encodeUtf8 _v2))) $ voteRequest_candidateId record
  , (\_v2 -> P.Just (2, ("term",T.TI64 _v2))) $ voteRequest_term record
  , (\_v2 -> P.Just (3, ("lastLogTerm",T.TI64 _v2))) $ voteRequest_lastLogTerm record
  , (\_v2 -> P.Just (4, ("lastLogIndex",T.TI32 _v2))) $ voteRequest_lastLogIndex record
  ]
write_VoteRequest :: T.Protocol p => p -> VoteRequest -> P.IO ()
write_VoteRequest oprot record = T.writeVal oprot $ from_VoteRequest record
encode_VoteRequest :: T.StatelessProtocol p => p -> VoteRequest -> LBS.ByteString
encode_VoteRequest oprot record = T.serializeVal oprot $ from_VoteRequest record
to_VoteRequest :: T.ThriftVal -> VoteRequest
to_VoteRequest (T.TStruct fields) = VoteRequest{
  voteRequest_candidateId = P.maybe (P.error "Missing required field: candidateId") (\(_,_val4) -> (case _val4 of {T.TString _val5 -> E.decodeUtf8 _val5; _ -> P.error "wrong type"})) (Map.lookup (1) fields),
  voteRequest_term = P.maybe (P.error "Missing required field: term") (\(_,_val4) -> (case _val4 of {T.TI64 _val6 -> _val6; _ -> P.error "wrong type"})) (Map.lookup (2) fields),
  voteRequest_lastLogTerm = P.maybe (P.error "Missing required field: lastLogTerm") (\(_,_val4) -> (case _val4 of {T.TI64 _val7 -> _val7; _ -> P.error "wrong type"})) (Map.lookup (3) fields),
  voteRequest_lastLogIndex = P.maybe (P.error "Missing required field: lastLogIndex") (\(_,_val4) -> (case _val4 of {T.TI32 _val8 -> _val8; _ -> P.error "wrong type"})) (Map.lookup (4) fields)
  }
to_VoteRequest _ = P.error "not a struct"
read_VoteRequest :: T.Protocol p => p -> P.IO VoteRequest
read_VoteRequest iprot = to_VoteRequest <$> T.readVal iprot (T.T_STRUCT typemap_VoteRequest)
decode_VoteRequest :: T.StatelessProtocol p => p -> LBS.ByteString -> VoteRequest
decode_VoteRequest iprot bs = to_VoteRequest $ T.deserializeVal iprot (T.T_STRUCT typemap_VoteRequest) bs
typemap_VoteRequest :: T.TypeMap
typemap_VoteRequest = Map.fromList [(1,("candidateId",T.T_STRING)),(2,("term",T.T_I64)),(3,("lastLogTerm",T.T_I64)),(4,("lastLogIndex",T.T_I32))]
default_VoteRequest :: VoteRequest
default_VoteRequest = VoteRequest{
  voteRequest_candidateId = "",
  voteRequest_term = 0,
  voteRequest_lastLogTerm = 0,
  voteRequest_lastLogIndex = 0}
data VoteResponse = VoteResponse  { voteResponse_term :: I.Int64
  , voteResponse_granted :: P.Bool
  } deriving (P.Show,P.Eq,G.Generic,TY.Typeable)
instance H.Hashable VoteResponse where
  hashWithSalt salt record = salt   `H.hashWithSalt` voteResponse_term record   `H.hashWithSalt` voteResponse_granted record  
instance QC.Arbitrary VoteResponse where 
  arbitrary = M.liftM VoteResponse (QC.arbitrary)
          `M.ap`(QC.arbitrary)
  shrink obj | obj == default_VoteResponse = []
             | P.otherwise = M.catMaybes
    [ if obj == default_VoteResponse{voteResponse_term = voteResponse_term obj} then P.Nothing else P.Just $ default_VoteResponse{voteResponse_term = voteResponse_term obj}
    , if obj == default_VoteResponse{voteResponse_granted = voteResponse_granted obj} then P.Nothing else P.Just $ default_VoteResponse{voteResponse_granted = voteResponse_granted obj}
    ]
from_VoteResponse :: VoteResponse -> T.ThriftVal
from_VoteResponse record = T.TStruct $ Map.fromList $ M.catMaybes
  [ (\_v11 -> P.Just (1, ("term",T.TI64 _v11))) $ voteResponse_term record
  , (\_v11 -> P.Just (2, ("granted",T.TBool _v11))) $ voteResponse_granted record
  ]
write_VoteResponse :: T.Protocol p => p -> VoteResponse -> P.IO ()
write_VoteResponse oprot record = T.writeVal oprot $ from_VoteResponse record
encode_VoteResponse :: T.StatelessProtocol p => p -> VoteResponse -> LBS.ByteString
encode_VoteResponse oprot record = T.serializeVal oprot $ from_VoteResponse record
to_VoteResponse :: T.ThriftVal -> VoteResponse
to_VoteResponse (T.TStruct fields) = VoteResponse{
  voteResponse_term = P.maybe (P.error "Missing required field: term") (\(_,_val13) -> (case _val13 of {T.TI64 _val14 -> _val14; _ -> P.error "wrong type"})) (Map.lookup (1) fields),
  voteResponse_granted = P.maybe (P.error "Missing required field: granted") (\(_,_val13) -> (case _val13 of {T.TBool _val15 -> _val15; _ -> P.error "wrong type"})) (Map.lookup (2) fields)
  }
to_VoteResponse _ = P.error "not a struct"
read_VoteResponse :: T.Protocol p => p -> P.IO VoteResponse
read_VoteResponse iprot = to_VoteResponse <$> T.readVal iprot (T.T_STRUCT typemap_VoteResponse)
decode_VoteResponse :: T.StatelessProtocol p => p -> LBS.ByteString -> VoteResponse
decode_VoteResponse iprot bs = to_VoteResponse $ T.deserializeVal iprot (T.T_STRUCT typemap_VoteResponse) bs
typemap_VoteResponse :: T.TypeMap
typemap_VoteResponse = Map.fromList [(1,("term",T.T_I64)),(2,("granted",T.T_BOOL))]
default_VoteResponse :: VoteResponse
default_VoteResponse = VoteResponse{
  voteResponse_term = 0,
  voteResponse_granted = P.False}
data AppendRequest = AppendRequest  { appendRequest_term :: I.Int64
  , appendRequest_leaderId :: LT.Text
  , appendRequest_prevLogIndex :: I.Int32
  , appendRequest_prevLogTerm :: I.Int64
  , appendRequest_leaderCommitIndex :: I.Int32
  , appendRequest_entries :: (Vector.Vector LogEntry)
  } deriving (P.Show,P.Eq,G.Generic,TY.Typeable)
instance H.Hashable AppendRequest where
  hashWithSalt salt record = salt   `H.hashWithSalt` appendRequest_term record   `H.hashWithSalt` appendRequest_leaderId record   `H.hashWithSalt` appendRequest_prevLogIndex record   `H.hashWithSalt` appendRequest_prevLogTerm record   `H.hashWithSalt` appendRequest_leaderCommitIndex record   `H.hashWithSalt` appendRequest_entries record  
instance QC.Arbitrary AppendRequest where 
  arbitrary = M.liftM AppendRequest (QC.arbitrary)
          `M.ap`(QC.arbitrary)
          `M.ap`(QC.arbitrary)
          `M.ap`(QC.arbitrary)
          `M.ap`(QC.arbitrary)
          `M.ap`(QC.arbitrary)
  shrink obj | obj == default_AppendRequest = []
             | P.otherwise = M.catMaybes
    [ if obj == default_AppendRequest{appendRequest_term = appendRequest_term obj} then P.Nothing else P.Just $ default_AppendRequest{appendRequest_term = appendRequest_term obj}
    , if obj == default_AppendRequest{appendRequest_leaderId = appendRequest_leaderId obj} then P.Nothing else P.Just $ default_AppendRequest{appendRequest_leaderId = appendRequest_leaderId obj}
    , if obj == default_AppendRequest{appendRequest_prevLogIndex = appendRequest_prevLogIndex obj} then P.Nothing else P.Just $ default_AppendRequest{appendRequest_prevLogIndex = appendRequest_prevLogIndex obj}
    , if obj == default_AppendRequest{appendRequest_prevLogTerm = appendRequest_prevLogTerm obj} then P.Nothing else P.Just $ default_AppendRequest{appendRequest_prevLogTerm = appendRequest_prevLogTerm obj}
    , if obj == default_AppendRequest{appendRequest_leaderCommitIndex = appendRequest_leaderCommitIndex obj} then P.Nothing else P.Just $ default_AppendRequest{appendRequest_leaderCommitIndex = appendRequest_leaderCommitIndex obj}
    , if obj == default_AppendRequest{appendRequest_entries = appendRequest_entries obj} then P.Nothing else P.Just $ default_AppendRequest{appendRequest_entries = appendRequest_entries obj}
    ]
from_AppendRequest :: AppendRequest -> T.ThriftVal
from_AppendRequest record = T.TStruct $ Map.fromList $ M.catMaybes
  [ (\_v18 -> P.Just (1, ("term",T.TI64 _v18))) $ appendRequest_term record
  , (\_v18 -> P.Just (2, ("leaderId",T.TString $ E.encodeUtf8 _v18))) $ appendRequest_leaderId record
  , (\_v18 -> P.Just (3, ("prevLogIndex",T.TI32 _v18))) $ appendRequest_prevLogIndex record
  , (\_v18 -> P.Just (4, ("prevLogTerm",T.TI64 _v18))) $ appendRequest_prevLogTerm record
  , (\_v18 -> P.Just (5, ("leaderCommitIndex",T.TI32 _v18))) $ appendRequest_leaderCommitIndex record
  , (\_v18 -> P.Just (6, ("entries",T.TList (T.T_STRUCT typemap_LogEntry) $ P.map (\_v20 -> from_LogEntry _v20) $ Vector.toList _v18))) $ appendRequest_entries record
  ]
write_AppendRequest :: T.Protocol p => p -> AppendRequest -> P.IO ()
write_AppendRequest oprot record = T.writeVal oprot $ from_AppendRequest record
encode_AppendRequest :: T.StatelessProtocol p => p -> AppendRequest -> LBS.ByteString
encode_AppendRequest oprot record = T.serializeVal oprot $ from_AppendRequest record
to_AppendRequest :: T.ThriftVal -> AppendRequest
to_AppendRequest (T.TStruct fields) = AppendRequest{
  appendRequest_term = P.maybe (P.error "Missing required field: term") (\(_,_val22) -> (case _val22 of {T.TI64 _val23 -> _val23; _ -> P.error "wrong type"})) (Map.lookup (1) fields),
  appendRequest_leaderId = P.maybe (P.error "Missing required field: leaderId") (\(_,_val22) -> (case _val22 of {T.TString _val24 -> E.decodeUtf8 _val24; _ -> P.error "wrong type"})) (Map.lookup (2) fields),
  appendRequest_prevLogIndex = P.maybe (P.error "Missing required field: prevLogIndex") (\(_,_val22) -> (case _val22 of {T.TI32 _val25 -> _val25; _ -> P.error "wrong type"})) (Map.lookup (3) fields),
  appendRequest_prevLogTerm = P.maybe (P.error "Missing required field: prevLogTerm") (\(_,_val22) -> (case _val22 of {T.TI64 _val26 -> _val26; _ -> P.error "wrong type"})) (Map.lookup (4) fields),
  appendRequest_leaderCommitIndex = P.maybe (P.error "Missing required field: leaderCommitIndex") (\(_,_val22) -> (case _val22 of {T.TI32 _val27 -> _val27; _ -> P.error "wrong type"})) (Map.lookup (5) fields),
  appendRequest_entries = P.maybe (P.error "Missing required field: entries") (\(_,_val22) -> (case _val22 of {T.TList _ _val28 -> (Vector.fromList $ P.map (\_v29 -> (case _v29 of {T.TStruct _val30 -> (to_LogEntry (T.TStruct _val30)); _ -> P.error "wrong type"})) _val28); _ -> P.error "wrong type"})) (Map.lookup (6) fields)
  }
to_AppendRequest _ = P.error "not a struct"
read_AppendRequest :: T.Protocol p => p -> P.IO AppendRequest
read_AppendRequest iprot = to_AppendRequest <$> T.readVal iprot (T.T_STRUCT typemap_AppendRequest)
decode_AppendRequest :: T.StatelessProtocol p => p -> LBS.ByteString -> AppendRequest
decode_AppendRequest iprot bs = to_AppendRequest $ T.deserializeVal iprot (T.T_STRUCT typemap_AppendRequest) bs
typemap_AppendRequest :: T.TypeMap
typemap_AppendRequest = Map.fromList [(1,("term",T.T_I64)),(2,("leaderId",T.T_STRING)),(3,("prevLogIndex",T.T_I32)),(4,("prevLogTerm",T.T_I64)),(5,("leaderCommitIndex",T.T_I32)),(6,("entries",(T.T_LIST (T.T_STRUCT typemap_LogEntry))))]
default_AppendRequest :: AppendRequest
default_AppendRequest = AppendRequest{
  appendRequest_term = 0,
  appendRequest_leaderId = "",
  appendRequest_prevLogIndex = 0,
  appendRequest_prevLogTerm = 0,
  appendRequest_leaderCommitIndex = 0,
  appendRequest_entries = Vector.empty}
data AppendResponse = AppendResponse  { appendResponse_term :: I.Int64
  , appendResponse_success :: P.Bool
  } deriving (P.Show,P.Eq,G.Generic,TY.Typeable)
instance H.Hashable AppendResponse where
  hashWithSalt salt record = salt   `H.hashWithSalt` appendResponse_term record   `H.hashWithSalt` appendResponse_success record  
instance QC.Arbitrary AppendResponse where 
  arbitrary = M.liftM AppendResponse (QC.arbitrary)
          `M.ap`(QC.arbitrary)
  shrink obj | obj == default_AppendResponse = []
             | P.otherwise = M.catMaybes
    [ if obj == default_AppendResponse{appendResponse_term = appendResponse_term obj} then P.Nothing else P.Just $ default_AppendResponse{appendResponse_term = appendResponse_term obj}
    , if obj == default_AppendResponse{appendResponse_success = appendResponse_success obj} then P.Nothing else P.Just $ default_AppendResponse{appendResponse_success = appendResponse_success obj}
    ]
from_AppendResponse :: AppendResponse -> T.ThriftVal
from_AppendResponse record = T.TStruct $ Map.fromList $ M.catMaybes
  [ (\_v33 -> P.Just (1, ("term",T.TI64 _v33))) $ appendResponse_term record
  , (\_v33 -> P.Just (2, ("success",T.TBool _v33))) $ appendResponse_success record
  ]
write_AppendResponse :: T.Protocol p => p -> AppendResponse -> P.IO ()
write_AppendResponse oprot record = T.writeVal oprot $ from_AppendResponse record
encode_AppendResponse :: T.StatelessProtocol p => p -> AppendResponse -> LBS.ByteString
encode_AppendResponse oprot record = T.serializeVal oprot $ from_AppendResponse record
to_AppendResponse :: T.ThriftVal -> AppendResponse
to_AppendResponse (T.TStruct fields) = AppendResponse{
  appendResponse_term = P.maybe (P.error "Missing required field: term") (\(_,_val35) -> (case _val35 of {T.TI64 _val36 -> _val36; _ -> P.error "wrong type"})) (Map.lookup (1) fields),
  appendResponse_success = P.maybe (P.error "Missing required field: success") (\(_,_val35) -> (case _val35 of {T.TBool _val37 -> _val37; _ -> P.error "wrong type"})) (Map.lookup (2) fields)
  }
to_AppendResponse _ = P.error "not a struct"
read_AppendResponse :: T.Protocol p => p -> P.IO AppendResponse
read_AppendResponse iprot = to_AppendResponse <$> T.readVal iprot (T.T_STRUCT typemap_AppendResponse)
decode_AppendResponse :: T.StatelessProtocol p => p -> LBS.ByteString -> AppendResponse
decode_AppendResponse iprot bs = to_AppendResponse $ T.deserializeVal iprot (T.T_STRUCT typemap_AppendResponse) bs
typemap_AppendResponse :: T.TypeMap
typemap_AppendResponse = Map.fromList [(1,("term",T.T_I64)),(2,("success",T.T_BOOL))]
default_AppendResponse :: AppendResponse
default_AppendResponse = AppendResponse{
  appendResponse_term = 0,
  appendResponse_success = P.False}
data LogEntry = LogEntry  { logEntry_command :: LT.Text
  , logEntry_term :: I.Int64
  } deriving (P.Show,P.Eq,G.Generic,TY.Typeable)
instance H.Hashable LogEntry where
  hashWithSalt salt record = salt   `H.hashWithSalt` logEntry_command record   `H.hashWithSalt` logEntry_term record  
instance QC.Arbitrary LogEntry where 
  arbitrary = M.liftM LogEntry (QC.arbitrary)
          `M.ap`(QC.arbitrary)
  shrink obj | obj == default_LogEntry = []
             | P.otherwise = M.catMaybes
    [ if obj == default_LogEntry{logEntry_command = logEntry_command obj} then P.Nothing else P.Just $ default_LogEntry{logEntry_command = logEntry_command obj}
    , if obj == default_LogEntry{logEntry_term = logEntry_term obj} then P.Nothing else P.Just $ default_LogEntry{logEntry_term = logEntry_term obj}
    ]
from_LogEntry :: LogEntry -> T.ThriftVal
from_LogEntry record = T.TStruct $ Map.fromList $ M.catMaybes
  [ (\_v40 -> P.Just (1, ("command",T.TString $ E.encodeUtf8 _v40))) $ logEntry_command record
  , (\_v40 -> P.Just (2, ("term",T.TI64 _v40))) $ logEntry_term record
  ]
write_LogEntry :: T.Protocol p => p -> LogEntry -> P.IO ()
write_LogEntry oprot record = T.writeVal oprot $ from_LogEntry record
encode_LogEntry :: T.StatelessProtocol p => p -> LogEntry -> LBS.ByteString
encode_LogEntry oprot record = T.serializeVal oprot $ from_LogEntry record
to_LogEntry :: T.ThriftVal -> LogEntry
to_LogEntry (T.TStruct fields) = LogEntry{
  logEntry_command = P.maybe (P.error "Missing required field: command") (\(_,_val42) -> (case _val42 of {T.TString _val43 -> E.decodeUtf8 _val43; _ -> P.error "wrong type"})) (Map.lookup (1) fields),
  logEntry_term = P.maybe (P.error "Missing required field: term") (\(_,_val42) -> (case _val42 of {T.TI64 _val44 -> _val44; _ -> P.error "wrong type"})) (Map.lookup (2) fields)
  }
to_LogEntry _ = P.error "not a struct"
read_LogEntry :: T.Protocol p => p -> P.IO LogEntry
read_LogEntry iprot = to_LogEntry <$> T.readVal iprot (T.T_STRUCT typemap_LogEntry)
decode_LogEntry :: T.StatelessProtocol p => p -> LBS.ByteString -> LogEntry
decode_LogEntry iprot bs = to_LogEntry $ T.deserializeVal iprot (T.T_STRUCT typemap_LogEntry) bs
typemap_LogEntry :: T.TypeMap
typemap_LogEntry = Map.fromList [(1,("command",T.T_STRING)),(2,("term",T.T_I64))]
default_LogEntry :: LogEntry
default_LogEntry = LogEntry{
  logEntry_command = "",
  logEntry_term = 0}
