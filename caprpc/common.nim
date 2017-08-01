import collections/iface, collections, collections/pprint
import caprpc/rpcschema, capnp
import reactor, macros, typetraits

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
  return f.then(proc(x: AnyPointer): Future[T] = catchError(castAs(x, T)))

proc castAs*[T](f: CapServer, ty: typedesc[T]): T =
  return f.toAnyPointer.castAs(T)

proc createFromCap*(t: typedesc[CapServer], cap: CapServer): CapServer =
  return cap

# GenericCapServer

type GenericCapServer*[T] = ref object of RootObj
  obj: T

proc call*[T](self: GenericCapServer[T], ifaceId: uint64, methodId: uint64, args: AnyPointer): Future[AnyPointer] =
  mixin capCall, getInterfaceId
  if getInterfaceId(T) != ifaceId:
    return now(error(AnyPointer, "calling invalid interface %1 on %2" % [$ifaceId, name(T)]))

  return capCall(self.obj, methodId, args)

proc toGenericCapServer*[T](obj: T): CapServer =
  return GenericCapServer[T](obj: obj).asCapServer

# capServerImpl

macro capServerImpl*(impl, ifaces): untyped =
  var ifaces = ifaces
  let implName = impl.repr

  if ifaces.kind != nnkBracket:
    ifaces = newNimNode(nnkBracket).add(ifaces)

  let GenericCapServer = genSym(nskType, "GenericCapServer_" & ($impl))
  let ifaceIdSym = genSym(nskParam, "ifaceId")
  let selfSym = genSym(nskParam, "self")
  let methodIdSym = genSym(nskParam, "methodId")
  let argsSym = genSym(nskParam, "args")

  let callFunc = quote do:
    proc call*(`selfSym`: `GenericCapServer`, `ifaceIdSym`: uint64, `methodIdSym`: uint64, `argsSym`: AnyPointer): Future[AnyPointer] =
      discard

  for iface in ifaces:
    callFunc[0].body.add(quote do:
      if getInterfaceId(`iface`) == `ifaceIdSym`:
        return capCall(`selfSym`.obj.asInterface(`iface`), `methodIdSym`, `argsSym`))

  callFunc[0].body.add(quote do:
    return now(error(AnyPointer, "object $1 does not implement this interface ($2)" % [`implName`, $`ifaceIdSym`])))

  let body = quote do:
    type `GenericCapServer` = ref object of RootObj
      obj: `impl`

    proc toCapServer*(obj: `impl`): CapServer

    `callFunc`

    proc toCapServer(obj: `impl`): CapServer =
      return `GenericCapServer`(obj: obj).asCapServer

  return body

# NothingImplemented

proc inlineCap*[T, R](ty: typedesc[T], impl: R): T =
  let implIface = impl.asInterface(T)
  when ty isnot CapServer:
    impl.toCapServer = (proc(): CapServer = return toGenericCapServer(implIface))
  return implIface

# nothingImplemented

let nothingImplemented* = inlineCap(CapServer, CapServerInlineImpl(
  call: (proc(ifaceId: uint64, methodId: uint64, args: AnyPointer): Future[AnyPointer] =
             return now(error(AnyPointer, "not implemented")))
))

# null cap

type NullCapT* = ref object of RootObj

let nullCap* = NullCapT()

proc call*(self: NullCapT, ifaceId: uint64, methodId: uint64, args: AnyPointer): Future[AnyPointer] =
  return now(error(AnyPointer, "null capability called"))

let nullCapInterface = NullCapT().asCapServer

converter toCapServer*(x: NullCapT): CapServer =
  return nullCapInterface

proc isNullCap*(cap: CapServer): bool =
  return cap.Interface.obj == nullCapInterface.Interface.obj and cap.Interface.vtable == nullCapInterface.Interface.vtable

# injectCap

proc injectInterface*(default: CapServer, interfaces: seq[uint64], joinWith: CapServer): CapServer =
  return inlineCap(CapServer,
                   CapServerInlineImpl(call: proc(ifaceId: uint64, methodId: uint64, args: AnyPointer): Future[AnyPointer] =
                                                 if ifaceId in interfaces:
                                                   return joinWith.call(ifaceId, methodId, args)
                                                 else:
                                                   return default.call(ifaceId, methodId, args)))

proc injectInterface*(default: CapServer, interfaceT: typedesc, joinWith: CapServer): CapServer =
  mixin getInterfaceId
  return injectInterface(default, @[getInterfaceId(interfaceT)], joinWith)

proc injectInterface*[T](default: T, interfaceT: typedesc, joinWith: CapServer): T =
  mixin getInterfaceId, toCapServer, castAs
  return injectInterface(default.toCapServer, @[getInterfaceId(interfaceT)], joinWith).castAs(T)

# restrictInterfaces

proc restrictInterfaces*(self: CapServer, interfaces: seq[uint64]): CapServer =
  return inlineCap(CapServer,
                   CapServerInlineImpl(call: proc(ifaceId: uint64, methodId: uint64, args: AnyPointer): Future[AnyPointer] =
                                                 if ifaceId in interfaces:
                                                   return self.call(ifaceId, methodId, args)
                                                 else:
                                                   return now(error(AnyPointer, "not implemented"))))

proc restrictInterfaces*(self: CapServer, interfaceT: typedesc): CapServer =
  mixin getInterfaceId
  return self.restrictInterfaces(@[getInterfaceId(interfaceT)])

proc restrictInterfaces*[T, R](self: T, interfaceT: typedesc[R]): R =
  mixin getInterfaceId, toCapServer
  return self.toCapServer.restrictInterfaces(@[getInterfaceId(interfaceT)]).castAs(R)

# gcDestroyingWrapper

type GcDestroyingWrapper = ref object of RootRef
  wrapped: CapServer
  destroyCallback: proc()

proc call*(self: GcDestroyingWrapper, ifaceId: uint64, methodId: uint64, args: AnyPointer): Future[AnyPointer] =
  return self.wrapped.call(ifaceId, methodId, args)

proc gcDestroyingWrapperDestroy(self: GcDestroyingWrapper) =
  self.destroyCallback()

proc gcDestroyingWrapper*(wrapped: CapServer, destroyCallback: proc()): CapServer =
  var r: GcDestroyingWrapper
  new(r, gcDestroyingWrapperDestroy)
  r.wrapped = wrapped
  r.destroyCallback = destroyCallback
  return r.asCapServer

proc gcDestroyingWrapper*[T](cap: T, destroyCallback: proc()): T =
  mixin toCapServer
  return gcDestroyingWrapper(cap.toCapServer, destroyCallback).castAs(T)

# testCopy

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
