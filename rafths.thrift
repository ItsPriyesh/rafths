struct VoteRequest {
	1: required string candidateId,
	2: required i64 term,
	3: required i64 lastLogTerm,
	4: required i32 lastLogIndex
}

struct VoteResponse {
	1: required i64 term,
	2: required bool granted
}

struct AppendRequest {
	1: required i64 term,
  2: required string leaderId,
  3: required i32 prevLogIndex,
  4: required i64 prevLogTerm,
  5: required i32 leaderCommitIndex,
  6: required list<LogEntry> entries
}

struct AppendResponse {
 1: required i64 term,
 2: required bool success
}

struct LogEntry {
	1: required string command,
	2: required i64 term
}

service RaftNodeService {
  VoteResponse requestVote(1: VoteRequest req);
  AppendResponse appendEntries(1: AppendRequest req);
}

