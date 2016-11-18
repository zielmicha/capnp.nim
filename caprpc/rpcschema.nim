import capnp, capnp/gensupport
type
  Call* = ref object
    questionId*: uint32
    target*: MessageTarget
    interfaceId*: uint64
    methodId*: uint16
    params*: Payload
    sendResultsTo*: Call_sendResultsTo
    allowThirdPartyTailCall*: bool

  CapDescriptorKind* {.pure.} = enum
    none = 0, senderHosted = 1, senderPromise = 2, receiverHosted = 3, receiverAnswer = 4, thirdPartyHosted = 5

  CapDescriptor* = ref object
    case kind*: CapDescriptorKind:
    of CapDescriptorKind.none:
      discard
    of CapDescriptorKind.senderHosted:
      senderHosted*: uint32
    of CapDescriptorKind.senderPromise:
      senderPromise*: uint32
    of CapDescriptorKind.receiverHosted:
      receiverHosted*: uint32
    of CapDescriptorKind.receiverAnswer:
      receiverAnswer*: PromisedAnswer
    of CapDescriptorKind.thirdPartyHosted:
      thirdPartyHosted*: ThirdPartyCapDescriptor

  MessageKind* {.pure.} = enum
    unimplemented = 0, abort = 1, call = 2, `return` = 3, finish = 4, resolve = 5, release = 6, obsoleteSave = 7, bootstrap = 8, obsoleteDelete = 9, provide = 10, accept = 11, join = 12, disembargo = 13

  Message* = ref object
    case kind*: MessageKind:
    of MessageKind.unimplemented:
      unimplemented*: Message
    of MessageKind.abort:
      abort*: Exception
    of MessageKind.call:
      call*: Call
    of MessageKind.`return`:
      `return`*: Return
    of MessageKind.finish:
      finish*: Finish
    of MessageKind.resolve:
      resolve*: Resolve
    of MessageKind.release:
      release*: Release
    of MessageKind.obsoleteSave:
      discard
    of MessageKind.bootstrap:
      bootstrap*: Bootstrap
    of MessageKind.obsoleteDelete:
      discard
    of MessageKind.provide:
      provide*: Provide
    of MessageKind.accept:
      accept*: Accept
    of MessageKind.join:
      join*: Join
    of MessageKind.disembargo:
      disembargo*: Disembargo

  MessageTargetKind* {.pure.} = enum
    importedCap = 0, promisedAnswer = 1

  MessageTarget* = ref object
    case kind*: MessageTargetKind:
    of MessageTargetKind.importedCap:
      importedCap*: uint32
    of MessageTargetKind.promisedAnswer:
      promisedAnswer*: PromisedAnswer

  Payload* = ref object
    content*: AnyPointer
    capTable*: seq[CapDescriptor]

  Provide* = ref object
    questionId*: uint32
    target*: MessageTarget
    recipient*: AnyPointer

  ReturnKind* {.pure.} = enum
    results = 0, exception = 1, canceled = 2, resultsSentElsewhere = 3, takeFromOtherQuestion = 4, acceptFromThirdParty = 5

  Return* = ref object
    answerId*: uint32
    releaseParamCaps*: bool
    case kind*: ReturnKind:
    of ReturnKind.results:
      results*: Payload
    of ReturnKind.exception:
      exception*: Exception
    of ReturnKind.canceled:
      discard
    of ReturnKind.resultsSentElsewhere:
      discard
    of ReturnKind.takeFromOtherQuestion:
      takeFromOtherQuestion*: uint32
    of ReturnKind.acceptFromThirdParty:
      discard

  Release* = ref object
    id*: uint32
    referenceCount*: uint32

  Exception_Type* {.pure.} = enum
    failed = 0, overloaded = 1, disconnected = 2, unimplemented = 3

  ResolveKind* {.pure.} = enum
    cap = 0, exception = 1

  Resolve* = ref object
    promiseId*: uint32
    case kind*: ResolveKind:
    of ResolveKind.cap:
      cap*: CapDescriptor
    of ResolveKind.exception:
      exception*: Exception

  ThirdPartyCapDescriptor* = ref object
    id*: AnyPointer
    vineId*: uint32

  Finish* = ref object
    questionId*: uint32
    releaseResultCaps*: bool

  Accept* = ref object
    questionId*: uint32
    provision*: AnyPointer
    embargo*: bool

  Disembargo_contextKind* {.pure.} = enum
    senderLoopback = 0, receiverLoopback = 1, accept = 2, provide = 3

  Disembargo_context* = object
    case kind*: Disembargo_contextKind:
    of Disembargo_contextKind.senderLoopback:
      senderLoopback*: uint32
    of Disembargo_contextKind.receiverLoopback:
      receiverLoopback*: uint32
    of Disembargo_contextKind.accept:
      discard
    of Disembargo_contextKind.provide:
      provide*: uint32

  Exception* = ref object
    reason*: string
    obsoleteIsCallersFault*: bool
    obsoleteDurability*: uint16
    `type`*: Exception_Type

  PromisedAnswer* = ref object
    questionId*: uint32
    transform*: seq[PromisedAnswer_Op]

  Call_sendResultsToKind* {.pure.} = enum
    caller = 0, yourself = 1, thirdParty = 2

  Call_sendResultsTo* = object
    case kind*: Call_sendResultsToKind:
    of Call_sendResultsToKind.caller:
      discard
    of Call_sendResultsToKind.yourself:
      discard
    of Call_sendResultsToKind.thirdParty:
      discard

  Bootstrap* = ref object
    questionId*: uint32
    deprecatedObjectId*: AnyPointer

  PromisedAnswer_OpKind* {.pure.} = enum
    noop = 0, getPointerField = 1

  PromisedAnswer_Op* = ref object
    case kind*: PromisedAnswer_OpKind:
    of PromisedAnswer_OpKind.noop:
      discard
    of PromisedAnswer_OpKind.getPointerField:
      getPointerField*: uint16

  Disembargo* = ref object
    target*: MessageTarget
    context*: Disembargo_context

  Join* = ref object
    questionId*: uint32
    target*: MessageTarget
    keyPart*: AnyPointer



makeStructCoders(Call, [
  (questionId, 0, 0, true),
  (interfaceId, 8, 0, true),
  (methodId, 4, 0, true)
  ], [
  (target, 0, PointerFlag.none, true),
  (params, 1, PointerFlag.none, true)
  ], [
  (allowThirdPartyTailCall, 128, false, true)
  ])

makeStructCoders(CapDescriptor, [
  (kind, 0, low(CapDescriptorKind), true),
  (senderHosted, 4, 0, CapDescriptorKind.senderHosted),
  (senderPromise, 4, 0, CapDescriptorKind.senderPromise),
  (receiverHosted, 4, 0, CapDescriptorKind.receiverHosted)
  ], [
  (receiverAnswer, 0, PointerFlag.none, CapDescriptorKind.receiverAnswer),
  (thirdPartyHosted, 0, PointerFlag.none, CapDescriptorKind.thirdPartyHosted)
  ], [])

makeStructCoders(Message, [
  (kind, 0, low(MessageKind), true)
  ], [
  (unimplemented, 0, PointerFlag.none, MessageKind.unimplemented),
  (abort, 0, PointerFlag.none, MessageKind.abort),
  (call, 0, PointerFlag.none, MessageKind.call),
  (`return`, 0, PointerFlag.none, MessageKind.`return`),
  (finish, 0, PointerFlag.none, MessageKind.finish),
  (resolve, 0, PointerFlag.none, MessageKind.resolve),
  (release, 0, PointerFlag.none, MessageKind.release),
  (bootstrap, 0, PointerFlag.none, MessageKind.bootstrap),
  (provide, 0, PointerFlag.none, MessageKind.provide),
  (accept, 0, PointerFlag.none, MessageKind.accept),
  (join, 0, PointerFlag.none, MessageKind.join),
  (disembargo, 0, PointerFlag.none, MessageKind.disembargo)
  ], [])

makeStructCoders(MessageTarget, [
  (kind, 4, low(MessageTargetKind), true),
  (importedCap, 0, 0, MessageTargetKind.importedCap)
  ], [
  (promisedAnswer, 0, PointerFlag.none, MessageTargetKind.promisedAnswer)
  ], [])

makeStructCoders(Payload, [], [
  (content, 0, PointerFlag.none, true),
  (capTable, 1, PointerFlag.none, true)
  ], [])

makeStructCoders(Provide, [
  (questionId, 0, 0, true)
  ], [
  (target, 0, PointerFlag.none, true),
  (recipient, 1, PointerFlag.none, true)
  ], [])

makeStructCoders(Return, [
  (answerId, 0, 0, true),
  (kind, 6, low(ReturnKind), true),
  (takeFromOtherQuestion, 8, 0, ReturnKind.takeFromOtherQuestion)
  ], [
  (results, 0, PointerFlag.none, ReturnKind.results),
  (exception, 0, PointerFlag.none, ReturnKind.exception)
  ], [
  (releaseParamCaps, 32, true, true)
  ])

makeStructCoders(Release, [
  (id, 0, 0, true),
  (referenceCount, 4, 0, true)
  ], [], [])

makeStructCoders(Resolve, [
  (promiseId, 0, 0, true),
  (kind, 4, low(ResolveKind), true)
  ], [
  (cap, 0, PointerFlag.none, ResolveKind.cap),
  (exception, 0, PointerFlag.none, ResolveKind.exception)
  ], [])

makeStructCoders(ThirdPartyCapDescriptor, [
  (vineId, 0, 0, true)
  ], [
  (id, 0, PointerFlag.none, true)
  ], [])

makeStructCoders(Finish, [
  (questionId, 0, 0, true)
  ], [], [
  (releaseResultCaps, 32, true, true)
  ])

makeStructCoders(Accept, [
  (questionId, 0, 0, true)
  ], [
  (provision, 0, PointerFlag.none, true)
  ], [
  (embargo, 32, false, true)
  ])

makeStructCoders(Disembargo_context, [
  (kind, 4, low(Disembargo_contextKind), true),
  (senderLoopback, 0, 0, Disembargo_contextKind.senderLoopback),
  (receiverLoopback, 0, 0, Disembargo_contextKind.receiverLoopback),
  (provide, 0, 0, Disembargo_contextKind.provide)
  ], [], [])

makeStructCoders(Exception, [
  (obsoleteDurability, 2, 0, true),
  (`type`, 4, Exception_Type(0), true)
  ], [
  (reason, 0, PointerFlag.text, true)
  ], [
  (obsoleteIsCallersFault, 0, false, true)
  ])

makeStructCoders(PromisedAnswer, [
  (questionId, 0, 0, true)
  ], [
  (transform, 0, PointerFlag.none, true)
  ], [])

makeStructCoders(Call_sendResultsTo, [
  (kind, 6, low(Call_sendResultsToKind), true)
  ], [], [])

makeStructCoders(Bootstrap, [
  (questionId, 0, 0, true)
  ], [
  (deprecatedObjectId, 0, PointerFlag.none, true)
  ], [])

makeStructCoders(PromisedAnswer_Op, [
  (kind, 0, low(PromisedAnswer_OpKind), true),
  (getPointerField, 2, 0, PromisedAnswer_OpKind.getPointerField)
  ], [], [])

makeStructCoders(Disembargo, [], [
  (target, 0, PointerFlag.none, true)
  ], [])

makeStructCoders(Join, [
  (questionId, 0, 0, true)
  ], [
  (target, 0, PointerFlag.none, true),
  (keyPart, 1, PointerFlag.none, true)
  ], [])


