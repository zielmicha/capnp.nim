import collections/iface
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

proc asAnyPointerFuture*[T](f: Future[T]): Future[AnyPointer] =
  return f.then(x => x.asAnyPointer)

proc castAs*[T](f: Future[AnyPointer], ty: typedesc[T]): Future[T] =
  return f.then(proc(x: AnyPointer): T = castAs(x, T))

proc createFromCap*(t: typedesc[CapServer], cap: CapServer): CapServer =
  return cap

# NothingImplemented
# TODO: inline interface

type
  NothingImplemented = ref object of RootObj

proc call(n: NothingImplemented, ifaceId: uint64, methodId: uint64, args: AnyPointer): Future[AnyPointer] {.async.} =
  asyncRaise "not implemented"

let nothingImplemented* = new(NothingImplemented).asInterface(CapServer)
