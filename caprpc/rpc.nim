## Implements the core of the RPC mechanism.
import caprpc/common, caprpc/util, caprpc/rpcschema, tables, collections/weaktable, reactor, capnp, collections/iface, caprpc/util

type
  RpcSystem* = ref object of WeakRefable
    network: VatNetwork
    myBootstrap: CapServer # my bootstrap interface

  Export = ref object of WeakRefable
    ## References receiver hosted capability.
    exportId: ExportId

  QuestionId = uint32
  AnswerId = uint32
  ExportId = uint32
  ImportId = uint32

  RpcConnection = ref object of WeakRefable
    system: WeakRef[RpcSystem]
    vatConn: Connection
    questions: QuestionTable[QuestionId, Question]

  Question = ref object

  Cap* = ref object
    ## Represents a capability (either sender or receiver hosted).
    case kind: CapDescriptorKind
    of CapDescriptorKind.none:
      discard
    of CapDescriptorKind.senderHosted:
      capServer: CapServer
    of {CapDescriptorKind.senderPromise, CapDescriptorKind.receiverHosted}:
      discard
    of CapDescriptorKind.receiverAnswer:
      discard
    of CapDescriptorKind.thirdPartyHosted:
      discard

proc newRpcSystem*(network: VatNetwork, myBootstrap: CapServer=nil): RpcSystem =
  return RpcSystem(
    network: network,
    myBootstrap: myBootstrap)

proc start(self: RpcConnection) {.async.} =
  asyncFor msg in self.vatConn.input:
    echo msg.repr

proc send(self: RpcConnection, msg: Message): Future[void] =
  return self.vatConn.output.provide(msg)

proc getConnection(self: RpcSystem, vatId: AnyPointer): RpcConnection =
  # TODO: cache connections
  let rpcConn = RpcConnection(system: self.weakRef, vatConn: self.network.connect(vatId))
  init(rpcConn.questions)
  rpcConn.start.ignore() # TODO: close connection on error
  return rpcConn

proc bootstrap*(self: RpcSystem, vatId: AnyPointer): Cap =
  let conn = self.getConnection(vatId)

  let fut = conn.send(Message(
    kind: MessageKind.bootstrap,
    bootstrap: Bootstrap(
      questionId: 0,
      deprecatedObjectId: nil
    )
  ))
  fut.ignore # FIXME

  return Cap()
