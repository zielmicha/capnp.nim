import collections/iface, collections, collections/pprint
import caprpc/rpcschema, capnp
import reactor

type
  VatNetwork* = distinct Interface

  VatId* = string # ...

  Connection* = object of Pipe[Message]

  CaprpcException* = object of system.Exception
    exceptionMsg*: rpcschema.Exception

  CapServerWrapper* = ref object of RootRef
    cap*: CapServer

interfaceMethods VatNetwork:
  connect(vatId: VatId): Connection
  ## Creates a Connection to a remote vat.
  ## If your connection is over TCP or other stream-based protocol,
  ## you may use wrapBytePipe to turn BytePipe into Pipe[Message].

  accept(): Future[Connection]
  ## Waits for connection from a remote vat.

  vatIdToPointer(v: VatId): AnyPointer
  ## Convert Vat ID into serializable form

  vatIdFromPointer(v: AnyPointer): VatId
  ## Convert Vat ID from serializable form

interfaceMethods CapServer:
  call(ifaceId: uint64, methodId: uint64, args: AnyPointer): Future[AnyPointer]
  ## Calls a method on this CapServer.

proc toAnyPointerFuture*[T](f: Future[T]): Future[AnyPointer] =
  return f.then(x => x.toAnyPointer)

proc castAs*[T](f: Future[AnyPointer], ty: typedesc[T]): Future[T] =
  return f.then(proc(x: AnyPointer): T = castAs(x, T))

proc createFromCap*(t: typedesc[CapServer], cap: CapServer): CapServer =
  return cap

# GenericCapServer

type GenericCapServer*[T] = ref object of RootObj
  obj: T

proc call*[T](self: GenericCapServer[T], ifaceId: uint64, methodId: uint64, args: AnyPointer): Future[AnyPointer] =
  mixin capCall, getInterfaceId
  if getInterfaceId(T) != ifaceId:
    return now(error(AnyPointer, "calling invalid interface"))

  return capCall(self.obj, methodId, args)

proc toGenericCapServer*[T](obj: T): CapServer =
  return GenericCapServer[T](obj: obj).asCapServer

template capServerImpl*(impl, iface) =
  proc toCapServer(self: impl): CapServer = return toGenericCapServer(self.asInterface(iface))


# NothingImplemented

proc inlineCap*[T, R](ty: typedesc[T], impl: R): T =
  let implIface = impl.asInterface(T)
  when ty isnot CapServer:
    impl.toCapServer = (proc(): CapServer = return toGenericCapServer(implIface))
  return implIface

let nothingImplemented* = inlineCap(CapServer, CapServerInlineImpl(
  call: (proc(ifaceId: uint64, methodId: uint64, args: AnyPointer): Future[AnyPointer] =
             return now(error(AnyPointer, "not implemented")))
))

type NullCapT* = ref object of RootObj

let nullCap* = NullCapT()

proc call*(self: NullCapT, ifaceId: uint64, methodId: uint64, args: AnyPointer): Future[AnyPointer] =
  return now(error(AnyPointer, "null capability called"))

let nullCapInterface = NullCapT().asCapServer

converter toCapServer*(x: NullCapT): CapServer =
  return nullCapInterface

proc isNullCap*(cap: CapServer): bool =
  return cap.Interface.obj == nullCapInterface.Interface.obj and cap.Interface.vtable == nullCapInterface.Interface.vtable

proc testCopy*[T](t: T) =
  ## Test if ``t`` serializes and unserialized correctly. Useful for debugging capnp.nim.
  let data = packPointerIgnoringCaps(t)
  echo data.encodeHex
  let unpacker = newUnpackerFlat(data)
  unpacker.getCap = proc(id: int): CapServer = return nothingImplemented
  echo unpacker.unpackPointer(0, T).pprint

  let packer = newPacker()
  packer.buffer &= "\0\0\0\0\0\0\0\0"
  copyPointer(unpacker, 0, packer, 8)
  assert packer.buffer[0..<8] == "\0\0\0\0\0\0\0\0"

  let copiedData = packer.buffer[8..<packer.buffer.len]
  echo copiedData.encodeHex

  let unpacker1 = newUnpackerFlat(copiedData)
  unpacker1.getCap = proc(id: int): CapServer = return nothingImplemented
  echo unpacker1.unpackPointer(0, T).pprint
