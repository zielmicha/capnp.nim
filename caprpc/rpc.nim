## Implements the core of the RPC mechanism.
import caprpc/common, caprpc/util, caprpc/rpcschema, tables, collections/weaktable, collections/weakref, reactor, capnp, collections/iface, caprpc/util, collections/iterate, collections, typetraits

type
  RpcSystem* = ref object
    network: VatNetwork
    myBootstrap: CapServer # my bootstrap interface
    connections: TableRef[VatId, VatConnection]

  QuestionId = uint32
  AnswerId = uint32
  ExportId = uint32
  ImportId = uint32

  VatConnection = ref object
    system: RpcSystem
    vatConn: Connection
    questions: QuestionTable[QuestionId, Question]
    answers: Table[AnswerId, Answer]
    exports: QuestionTable[ExportId, Export]
    imports: WeakValueTable[ImportId, RemoteCapObj]

  Answer = ref object
    result: Future[AnyPointer]

  Export = ref object
    refCount: int64
    cap: CapServer

  Question = ref object
    id: QuestionId
    returnCallback: (proc(ret: Return): Future[void])

  RemoteCapObj = object
    vatConnection: VatConnection
    importId: ImportId
    refCount: int64

  RemoteCap = WeakRefable[RemoteCapObj]

proc call(cap: RemoteCap, ifaceId: uint64, methodId: uint64, payload: AnyPointer): Future[AnyPointer] {.async.}
proc makePayload(self: VatConnection, payload: AnyPointer): Payload

proc newRpcSystem*(network: VatNetwork, myBootstrap: CapServer=nothingImplemented): RpcSystem =
  return RpcSystem(
    network: network,
    myBootstrap: myBootstrap,
    connections: newTable[VatId, VatConnection]())

proc send(self: VatConnection, msg: Message): Future[void] =
  when defined(caprpcTraceMessages):
    when defined(caprpcShowSendTrace):
      echo(getStackTrace())
    echo("\x1B[91msend\x1B[0m ", msg.pprint)
  return self.vatConn.output.send(msg)

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

proc catchInternalError[T](f: Future[T], self: VatConnection) =
  f.ignore # TODO

proc releaseCap(cap: ref RemoteCapObj) {.cdecl.} =
  when defined(caprpcTraceLifetime):
    echo "release ", cap.importId

  proc doRelease() =
    cap.vatConnection.send(Message(
      kind: MessageKind.release,
      release: Release(
        referenceCount: cap.refCount.uint32,
        id: cap.importId
      )
    )).catchInternalError(cap.vatConnection)

  doRelease()

proc getImportedCap(self: VatConnection, id: ImportId): CapServer =
  var cap: RemoteCap
  if id in self.imports:
    cap = self.imports[id]
  else:
    cap = self.imports.addKey(id, (ref RemoteCapObj)(
      vatConnection: self,
      importId: id
    ), freeCallback=releaseCap)

  cap.obj.refCount += 1
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
  payload.content.setCapGetter(proc(id: int): CapServer =
                                   if id == -1: return nullCap
                                   if id < 0 or id >= caps.len:
                                     raise newException(system.Exception, "invalid capability")
                                   return caps[id])
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

proc resolveTransform(item: AnyPointer, ops: seq[PromisedAnswer_Op]): AnyPointer =
  var item = item

  for op in ops:
    case op.kind:
    of PromisedAnswer_OpKind.noop:
      discard
    of PromisedAnswer_OpKind.getPointerField:
      item = item.getPointerField(op.getPointerField.int)

  return item

proc getTargetCap(self: VatConnection, target: MessageTarget): Future[CapServer] {.async.} =
  case target.kind:
  of MessageTargetKind.importedCap:
    let id = target.importedCap
    if id notin self.exports:
      asyncRaise "bad export ID"
    return self.exports[id].cap
  of MessageTargetKind.promisedAnswer:
    let promise = target.promisedAnswer
    if promise.questionId notin self.answers:
      asyncRaise "invalid question id"
    return self.answers[promise.questionId].result.then(
      x => x.resolveTransform(promise.transform).castAs(CapServer))

proc respondToCall(self: VatConnection, msg: Message, questionId: uint32, value: Result[AnyPointer]) {.async.} =
  var ret: Return

  if value.isSuccess:
    ret = Return(kind: ReturnKind.results,
                 results: self.makePayload(value.get),
                 answerId: questionId)
  else:
    when defined(caprpcPrintExceptions):
      value.error.printError
    ret = Return(kind: ReturnKind.exception,
                 exception: rpcschema.Exception(reason: $value),
                 answerId: questionId)

  await self.send(Message(kind: MessageKind.`return`, `return`: ret))

proc processMessage(self: VatConnection, msg: Message) {.async.} =
  case msg.kind:
    of MessageKind.unimplemented:
      stderr.writeLine("peer sent 'unimplemented' message")
    of MessageKind.abort:
      discard

    of {MessageKind.call, MessageKind.bootstrap}:
      let questionId = if msg.kind == MessageKind.bootstrap:
                         msg.bootstrap.questionId
                       else:
                         msg.call.questionId

      if questionId in self.answers:
        asyncRaise "question id reused"

      let callResult =
        if msg.kind == MessageKind.bootstrap:
          now(just(self.system.myBootstrap.toAnyPointer))
        else:
          self.getTargetCap(msg.call.target).then(
            target => target.call(msg.call.interfaceId, msg.call.methodId, self.unpackPayload(msg.call.params)))

      callResult.onSuccessOrError(
        proc(r: Result[AnyPointer]) = self.respondToCall(msg, questionId, r).catchInternalError(self))

      self.answers[questionId] = Answer(result: callResult)

    of MessageKind.`return`:
      let questionId = msg.`return`.answerId
      if msg.`return`.releaseParamCaps: echo("releaseParamCaps unsupported") # TODO
      if questionId notin self.questions:
        stderr.writeLine("peer sent return to invalid question")
      else:
        await self.questions[questionId].returnCallback(msg.`return`)

    of MessageKind.finish:
      # TODO: handle releaseResultCaps
      if msg.finish.releaseResultCaps:
        discard # answers[msg.finish.questionId].then(x => self.releasePtr(x)).ignore
      self.answers.del(msg.finish.questionId)

    of MessageKind.resolve:
      discard
    of MessageKind.release:
      when defined(caprpcTraceLifetime):
        stderr.writeLine("remote asks to release " & $msg.release.id)

      if msg.release.id notin self.exports:
        asyncRaise "bad release export id"

      let exportObj = self.exports[msg.release.id]
      exportObj.refCount -= msg.release.referenceCount.int64
      if exportObj.refCount == 0:
        when defined(caprpcTraceLifetime):
          let cap = self.exports[msg.release.id].cap
          stderr.writeLine("releasing export " & $msg.release.id & " refcnt after: " & $(getRefcount(cap.getImpl)-2) &
                           " cap: " & cap.pprint)

        del self.exports, msg.release.id
    of MessageKind.obsoleteSave:
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
    when defined(caprpcTraceMessages):
      echo("\x1B[92mrecv\x1B[0m ", msg.pprint)
    await self.processMessage(msg)

proc getConnection(self: RpcSystem, vatId: VatId): VatConnection =
  if vatId in self.connections:
    return self.connections[vatId]

  let rpcConn = VatConnection()
  self.connections[vatId] = rpcConn
  rpcConn.system = self
  rpcConn.vatConn = self.network.connect(vatId)
  rpcConn.questions = initQuestionTable[QuestionId, Question]()
  rpcConn.answers = initTable[AnswerId, Answer]()
  rpcConn.imports = newWeakValueTable[ImportId, RemoteCapObj]()
  rpcConn.exports = initQuestionTable[ExportId, Export]()
  when defined(caprpcTraceMessages):
    echo "creating new connection"

  # TODO: close connection on error
  rpcConn.start().onSuccessOrError(
    proc(r: Result[void]) =
      echo "RPC connection closed ", r
  )
  return rpcConn

proc initConnection*(self: RpcSystem, vatId: VatId) =
  ## Initialize connecting to vatId without bootstrapping. To be used by VatNetwork.
  discard self.getConnection(vatId)

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
    if remoteCap.obj.vatConnection == self:
      # TODO: refcount?
      return CapDescriptor(kind: CapDescriptorKind.receiverHosted, receiverHosted: remoteCap.obj.importId)

  let exportId = self.exports.putNext(Export(refCount: 1, cap: cap))
  return CapDescriptor(kind: CapDescriptorKind.senderHosted, senderHosted: exportId)

proc makePayload(self: VatConnection, payload: AnyPointer): Payload =
  var capTable: seq[CapDescriptor] = @[]

  proc capToIndex(cap: CapServer): int =
    if cap.isNullCap:
      return -1
    capTable.add(self.exportCap(cap))
    return capTable.len - 1

  let newPayload = payload.packNow(capToIndex)
  return Payload(content: newPayload, capTable: capTable) # TODO: caps

# RemoteCap impl

proc call(cap: RemoteCap, ifaceId: uint64, methodId: uint64, payload: AnyPointer): Future[AnyPointer] {.async.} =
  let conn = cap.obj.vatConnection
  let question = conn.newQuestion()

  await conn.send(Message(
    kind: MessageKind.call,
    call: Call(
      questionId: question.id,
      interfaceId: ifaceId,
      target: MessageTarget(kind: MessageTargetKind.importedCap,
                            importedCap: cap.obj.importId),
      methodId: methodId.uint16,
      params: conn.makePayload(payload),
      sendResultsTo: Call_sendResultsTo(kind: Call_sendResultsToKind.caller),
    )
  ))

  return (await conn.getFutureForQuestion(question))
