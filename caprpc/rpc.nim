## Implements the core of the RPC mechanism.
import caprpc/common

type
  RpcSystem = ref object
    network: VatNetwork
    bootstrap: CapServer
