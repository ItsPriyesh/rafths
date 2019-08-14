# rafths

rafths is a purely functional implementation of the [Raft consensus algorithm](https://raft.github.io) in Haskell. It uses Raft to maintain a fault tolerant distributed key-value store across a cluster of replicas. 

Each server exposes an HTTP API to allow inserts and lookups on the key-value store, but only the leader of the cluster may accept writes. Requests made to a server in the follower or candidate state will be automatically redirected to the current leader.

## Build
Generate Thrift RPC stubs/types and compile.
```
thrift -r --gen hs rafths.thrift
stack build
```

## Usage
For each server, specify the API port, the RPC port, and a config file defining all servers in the cluster.
```
stack exec -- rafths-exe 4041 8081 cluster.yaml
stack exec -- rafths-exe 4042 8082 cluster.yaml
stack exec -- rafths-exe 4043 8083 cluster.yaml
```

where `cluster.yaml` is
```
nodes:
  - host: "localhost"
    apiPort: 4041
    rpcPort: 8081
  - host: "localhost"
    apiPort: 4042
    rpcPort: 8082
  - host: "localhost"
    apiPort: 4043
    rpcPort: 8083
```

**Lookup (GET):** 

`curl http://localhost:4041/{key}`

**Insert (POST):**

`curl --data "value={value}" http://localhost:4041/{key}`
