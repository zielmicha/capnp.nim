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
    id: QuestionId
    returnCallback: (proc(ret: Return): Future[void])

  CapKind = enum
    selfHosted
    peerHosted
    peerPromise
    exception

  Cap* = ref object
    ## Represents a capability (either sender or receiver hosted).
    case kind: CapKind
    of CapKind.selfHosted:
      capServer: CapServer
      # this will be automatically exported during serialization
    of CapKind.peerHosted:
      importId: ImportId
    of CapKind.peerPromise:
      # currently we only support direct pipelining
      questionId: QuestionId
    of CapKind.exception:
      # error
      exception: rpcschema.Exception

proc newRpcSystem*(network: VatNetwork, myBootstrap: CapServer=nil): RpcSystem =
  return RpcSystem(
    network: network,
    myBootstrap: myBootstrap)

proc send(self: RpcConnection, msg: Message): Future[void] =
  echo("send ", msg.repr)
  return self.vatConn.output.provide(msg)

proc finishQuestion(self: RpcConnection, questionId: QuestionId): Future[void] {.async.} =
  await self.send(Message(
    kind: MessageKind.finish,
    finish: Finish(releaseResultCaps: false, questionId: questionId)
  ))
  del self.questions, questionId

proc newQuestion(self: RpcConnection): Question =
  let q = Question()
  q.id = self.questions.putNext(q)
  return q

proc asExportId(payload: Payload): ExportId =
  discard

proc getCapForQuestion(self: RpcConnection, question: Question): Cap =
  let cap = Cap(
    kind: CapKind.peerPromise,
    questionId: question.id
  )

  proc cb(ret: Return): Future[void] {.async.} =
    reset(cap[])
    case ret.kind:
      of ReturnKind.results:
        cap.kind = CapKind.peerHosted
        cap.importId = ret.results.asExportId
      of ReturnKind.exception:
        cap.kind = CapKind.exception
        cap.exception = ret.exception
      else:
        stderr.writeLine("unsupported return: ", ret.kind)

  question.returnCallback = cb

  return cap

proc processMessage(self: RpcConnection, msg: Message) {.async.} =
  case msg.kind:
    of MessageKind.unimplemented:
      stderr.writeLine("peer sent 'unimplemented' message")
    of MessageKind.abort:
      discard
    of MessageKind.call:
      discard
    of MessageKind.`return`:
      let questionId = msg.`return`.answerId
      let releaseParamCaps = msg.`return`.releaseParamCaps
      # TODO: releaseParamCaps
      if questionId notin self.questions:
        stderr.writeLine("peer sent return to invalid question")
      else:
        await self.questions[questionId].returnCallback(msg.`return`)
        await self.finishQuestion(questionId)
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

proc start(self: RpcConnection) {.async.} =
  asyncFor msg in self.vatConn.input:
    echo msg.repr
    await self.processMessage(msg)

proc getConnection(self: RpcSystem, vatId: AnyPointer): RpcConnection =
  # TODO: cache connections
  let rpcConn = RpcConnection(system: self.weakRef, vatConn: self.network.connect(vatId))
  init(rpcConn.questions)
  rpcConn.start.ignore() # TODO: close connection on error
  return rpcConn

proc bootstrap*(self: RpcSystem, vatId: AnyPointer): Cap =
  let conn = self.getConnection(vatId)
  let question = conn.newQuestion()

  let fut = conn.send(Message(
    kind: MessageKind.bootstrap,
    bootstrap: Bootstrap(
      questionId: question.id,
      deprecatedObjectId: nil
    )
  ))
  fut.ignore # FIXME

  return conn.getCapForQuestion(question)
