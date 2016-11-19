import capnp, capnp/gensupport
type
  RecipientId* = ref object

  JoinKeyPart* = ref object
    joinId*: uint32
    partCount*: uint16
    partNum*: uint16

  JoinResult* = ref object
    joinId*: uint32
    succeeded*: bool
    cap*: AnyPointer

  Side* {.pure.} = enum
    server = 0, client = 1

  ThirdPartyCapId* = ref object

  ProvisionId* = ref object
    joinId*: uint32

  VatId* = ref object
    side*: Side



makeStructCoders(RecipientId, [], [], [])

makeStructCoders(JoinKeyPart, [
  (joinId, 0, 0, true),
  (partCount, 4, 0, true),
  (partNum, 6, 0, true)
  ], [], [])

makeStructCoders(JoinResult, [
  (joinId, 0, 0, true)
  ], [
  (cap, 0, PointerFlag.none, true)
  ], [
  (succeeded, 32, false, true)
  ])

makeStructCoders(ThirdPartyCapId, [], [], [])

makeStructCoders(ProvisionId, [
  (joinId, 0, 0, true)
  ], [], [])

makeStructCoders(VatId, [
  (side, 0, Side(0), true)
  ], [], [])


