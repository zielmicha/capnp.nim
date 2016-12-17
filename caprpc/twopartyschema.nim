import capnp, capnp/gensupport, collections/iface

# file: caprpc/rpc-twoparty.capnp

type
  Side* {.pure.} = enum
    server = 0, client = 1

  VatId* = ref object
    side*: Side

  ProvisionId* = ref object
    joinId*: uint32

  RecipientId* = ref object

  ThirdPartyCapId* = ref object

  JoinKeyPart* = ref object
    joinId*: uint32
    partCount*: uint16
    partNum*: uint16

  JoinResult* = ref object
    joinId*: uint32
    succeeded*: bool
    cap*: AnyPointer



makeStructCoders(VatId, [
  (side, 0, Side(0), true)
  ], [], [])

makeStructCoders(ProvisionId, [
  (joinId, 0, 0, true)
  ], [], [])

makeStructCoders(RecipientId, [], [], [])

makeStructCoders(ThirdPartyCapId, [], [], [])

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


