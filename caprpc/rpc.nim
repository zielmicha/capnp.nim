## Implements the core of the RPC mechanism.
import caprpc/common, caprpc/util, caprpc/rpcschema, tables, collections/weaktable, reactor, capnp, collections/iface, caprpc/util, collections/iterate, collections

type
  RpcSystem* = ref object of WeakRefable
    network: VatNetwork
    myBootstrap: CapServer # my bootstrap interface
    connections: WeakValueTable[VatId, VatConnection]

  QuestionId = uint32
  AnswerId = uint32
  ExportId = uint32
  ImportId = uint32

  VatConnection = ref object of WeakRefable
    system: RpcSystem
    vatConn: Connection
    questions: QuestionTable[QuestionId, Question]
    exports: QuestionTable[ExportId, Export]
    imports: WeakValueTable[ImportId, RemoteCap]

  Export = ref object
    refCount: int64
    cap: CapServer

  Question = ref object
    id: QuestionId
    returnCallback: (proc(ret: Return): Future[void])

  RemoteCap = ref object of WeakRefable # implements CapServer
    vatConnection: VatConnection
    importId: ImportId
    refCount: int64

proc call(cap: RemoteCap, ifaceId: uint64, methodId: uint64, payload: AnyPointer): Future[AnyPointer]
proc makePayload(self: VatConnection, payload: AnyPointer): Payload

proc newRpcSystem*(network: VatNetwork, myBootstrap: CapServer=nothingImplemented): RpcSystem =
  return RpcSystem(
    network: network,
    myBootstrap: myBootstrap,
    connections: newWeakValueTable[VatId, VatConnection]())

proc send(self: VatConnection, msg: Message): Future[void] =
  when defined(traceMessages):
    when defined(showSendTrace):
      echo(getStackTrace())
    echo("\x1B[91msend\x1B[0m ", msg.pprint)
  return self.vatConn.output.provide(msg)

proc finishQuestion(self: VatConnection, questionId: QuestionId): Future[void] {.async.} =
  await self.send(Message(
    kind: MessageKind.finish,
    finish: Finish(releaseResultCaps: false, questionId: questionId)
  ))
  self.questions.del(questionId)

proc newQuestion(self: VatConnection): Question =
  let q = Question()
  q.id = self.questions.putNext(q)
  return q

proc getImportedCap(self: VatConnection, id: ImportId): CapServer =
  var cap: RemoteCap
  if id in self.imports:
    cap = self.imports[id]
  else:
    cap = self.imports.addKey(id)
    cap.vatConnection = self
    cap.importId = id

  cap.refCount += 1
  return cap.asCapServer

proc capFromDescriptor(self: VatConnection, descriptor: CapDescriptor): CapServer =
  case descriptor.kind:
  of CapDescriptorKind.none:
    return nothingImplemented
  of CapDescriptorKind.senderHosted:
    return self.getImportedCap(descriptor.senderHosted)
  of CapDescriptorKind.senderPromise:
    raise newException(system.Exception, "promise not implemented")
  of CapDescriptorKind.receiverHosted:
    let id = descriptor.receiverHosted
    if id notin self.exports:
      raise newException(system.Exception, "bad export ID")
    return self.exports[id].cap
  of CapDescriptorKind.receiverAnswer:
    return nothingImplemented
  of CapDescriptorKind.thirdPartyHosted:
    return nothingImplemented

proc unpackPayload(self: VatConnection, payload: Payload): AnyPointer =
  let caps = payload.capTable.map(x => self.capFromDescriptor(x)).toSeq
  payload.content.setCapGetter(proc(id: int): CapServer = caps[id])
  return payload.content

proc getFutureForQuestion(self: VatConnection, question: Question): Future[AnyPointer] =
  let completer = newCompleter[AnyPointer]()

  proc cb(ret: Return): Future[void] {.async.} =
    case ret.kind:
      of ReturnKind.results:
        completer.complete(self.unpackPayload(ret.results))
      of ReturnKind.exception:
        completer.completeError((ref CaprpcException)(
          exceptionMsg: ret.exception, msg: "server: " & nilToEmpty(ret.exception.reason)))
      else:
        stderr.writeLine("unsupported return: ", ret.kind)

    await self.finishQuestion(ret.answerId)

  question.returnCallback = cb

  return completer.getFuture

proc getTargetCap(self: VatConnection, target: MessageTarget): CapServer =
  case target.kind:
  of MessageTargetKind.importedCap:
    let id = target.importedCap
    if id notin self.exports:
      raise newException(system.Exception, "bad export ID")
    return self.exports[id].cap
  of MessageTargetKind.promisedAnswer:
    doAssert(false)

proc respondToCall(self: VatConnection, msg: Message, value: Result[AnyPointer]) {.async.} =
  var ret: Return

  if value.isSuccess:
    ret = Return(kind: ReturnKind.results, results: self.makePayload(value.get))
  else:
    ret = Return(kind: ReturnKind.exception, exception: rpcschema.Exception(reason: $value))

  await self.send(Message(kind: MessageKind.`return`, `return`: ret))

proc processMessage(self: VatConnection, msg: Message) {.async.} =
  case msg.kind:
    of MessageKind.unimplemented:
      stderr.writeLine("peer sent 'unimplemented' message")
    of MessageKind.abort:
      discard

    of MessageKind.call:
      let target = self.getTargetCap(msg.call.target)
      target.call(msg.call.interfaceId, msg.call.methodId, self.unpackPayload(msg.call.params)).onSuccessOrError(
        proc(ret: Result[AnyPointer]) =
          # TODO: close connection on failure
          self.respondToCall(msg, ret).ignore
      )

    of MessageKind.`return`:
      let questionId = msg.`return`.answerId
      let releaseParamCaps = msg.`return`.releaseParamCaps
      # TODO: releaseParamCaps
      if questionId notin self.questions:
        stderr.writeLine("peer sent return to invalid question")
      else:
        await self.questions[questionId].returnCallback(msg.`return`)

    of MessageKind.finish:
      discard
    of MessageKind.resolve:
      discard
    of MessageKind.release:
      discard
    of MessageKind.obsoleteSave:
      discard
    of MessageKind.bootstrap:
      discard
    of MessageKind.obsoleteDelete:
      discard
    of MessageKind.provide:
      discard
    of MessageKind.accept:
      discard
    of MessageKind.join:
      discard
    of MessageKind.disembargo:
      discard

proc start(self: VatConnection) {.async.} =
  asyncFor msg in self.vatConn.input:
    when defined(traceMessages):
      echo("\x1B[92mrecv\x1B[0m ", msg.pprint)
    await self.processMessage(msg)

proc getConnection(self: RpcSystem, vatId: VatId): VatConnection =
  if vatId in self.connections:
    return self.connections[vatId]

  let rpcConn = self.connections.addKey(vatId)
  rpcConn.system = self
  rpcConn.vatConn = self.network.connect(vatId)
  rpcConn.questions = initQuestionTable[QuestionId, Question]()
  rpcConn.imports = newWeakValueTable[ImportId, RemoteCap]()
  rpcConn.exports = initQuestionTable[ExportId, Export]()
  echo "creating new connection"

  rpcConn.start.ignore() # TODO: close connection on error
  return rpcConn

proc bootstrap*(self: RpcSystem, vatId: VatId): Future[AnyPointer] {.async.} =
  let conn = self.getConnection(vatId)
  let question = conn.newQuestion()

  # queue the message
  await conn.send(Message(
    kind: MessageKind.bootstrap,
    bootstrap: Bootstrap(
      questionId: question.id,
      deprecatedObjectId: nil
    )
  ))

  return (await conn.getFutureForQuestion(question))

proc exportCap(self: VatConnection, cap: CapServer): CapDescriptor =
  # TODO: no need to always export
  if cap.getImpl of RemoteCap:
    let remoteCap = cap.getImpl.RemoteCap
    if remoteCap.vatConnection == self:
      # TODO: refcount?
      return CapDescriptor(kind: CapDescriptorKind.receiverHosted, receiverHosted: remoteCap.importId)

  let exportId = self.exports.putNext(Export(refCount: 1, cap: cap))
  return CapDescriptor(kind: CapDescriptorKind.senderHosted, senderHosted: exportId)

proc makePayload(self: VatConnection, payload: AnyPointer): Payload =
  var capTable: seq[CapDescriptor] = @[]

  proc capToIndex(cap: CapServer): int =
    capTable.add(self.exportCap(cap))
    return capTable.len - 1

  let newPayload = payload.packNow(capToIndex)
  return Payload(content: newPayload, capTable: capTable) # TODO: caps

# RemoteCap impl

async:
 proc call(cap: RemoteCap, ifaceId: uint64, methodId: uint64, payload: AnyPointer): Future[AnyPointer] =
  let conn = cap.vatConnection
  let question = conn.newQuestion()

  await conn.send(Message(
    kind: MessageKind.call,
    call: Call(
      questionId: question.id,
      interfaceId: ifaceId,
      target: MessageTarget(kind: MessageTargetKind.importedCap,
                            importedCap: cap.importId),
      methodId: methodId.uint16,
      params: conn.makePayload(payload),
      sendResultsTo: Call_sendResultsTo(kind: Call_sendResultsToKind.caller),
    )
  ))

  return (await conn.getFutureForQuestion(question))
