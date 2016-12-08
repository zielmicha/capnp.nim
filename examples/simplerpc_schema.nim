import capnp, capnp/gensupport, collections/iface

import reactor, caprpc, caprpc/rpcgensupport
type
  SimpleRpc* = distinct Interface
  SimpleRpc_CallWrapper* = ref object of CapServerWrapper

  SimpleRpc_identity_Params* = ref object
    a*: int64

  SimpleRpc_dup_Result* = ref object
    b*: int64
    c*: int64

  SimpleRpc_identity_Result* = ref object
    b*: int64

  ContainsCap* = ref object
    cap*: SimpleRpc

  SimpleRpc_dup_Params* = ref object
    a*: int64



interfaceMethods SimpleRpc:
  toCapServer(): CapServer
  identity(a: int64): Future[int64]
  dup(a: int64): Future[SimpleRpc_dup_Result]

proc getIntefaceId*(t: typedesc[SimpleRpc]): uint64 = return 9832355072165603449'u64

miscCapMethods(SimpleRpc, SimpleRpc_CallWrapper)

proc capCall*[T: SimpleRpc](cap: T, id: uint64, args: AnyPointer): Future[AnyPointer] =
  case int(id):
    of 0:
      let argObj = args.castAs(SimpleRpc_identity_Params)
      let retVal = cap.identity(argObj.a)
      return wrapFutureInSinglePointer(SimpleRpc_identity_Result, b, retVal)
    of 1:
      let argObj = args.castAs(SimpleRpc_dup_Params)
      let retVal = cap.dup(argObj.a)
      return retVal.asAnyPointerFuture
    else: raise newException(NotImplementedError, "not implemented")

proc identity*[T: SimpleRpc_CallWrapper](self: T, a: int64): Future[int64] =
  return getFutureField(self.cap.call(9832355072165603449'u64, 0, toAnyPointer(SimpleRpc_identity_Params(a: a))).castAs(SimpleRpc_identity_Result), b)

proc dup*[T: SimpleRpc_CallWrapper](self: T, a: int64): Future[SimpleRpc_dup_Result] =
  return self.cap.call(9832355072165603449'u64, 1, toAnyPointer(SimpleRpc_dup_Params(a: a))).castAs(SimpleRpc_dup_Result)

makeStructCoders(SimpleRpc_identity_Params, [
  (a, 0, 0, true)
  ], [], [])

makeStructCoders(SimpleRpc_dup_Result, [
  (b, 0, 0, true),
  (c, 8, 0, true)
  ], [], [])

makeStructCoders(SimpleRpc_identity_Result, [
  (b, 0, 0, true)
  ], [], [])

makeStructCoders(ContainsCap, [], [
  (cap, 0, PointerFlag.none, true)
  ], [])

makeStructCoders(SimpleRpc_dup_Params, [
  (a, 0, 0, true)
  ], [], [])


