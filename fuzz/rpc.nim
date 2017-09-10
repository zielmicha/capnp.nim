import capnp, caprpc/rpcschema, posix, fuzzlib, collections

proc main() =
  try:
    let data = stdin.readAll
    let u = newUnpacker(data)
    let msg = u.unpackPointer(0, Message)

    let dataPacked = packPointer(msg)
    let msg1 = newUnpackerFlat(dataPacked).unpackPointer(0, Message)
    let dataPacked2 = packPointer(msg1)

    when not defined(fuzz):
      echo dataPacked.encodeHex
      echo dataPacked2.encodeHex

      echo msg.pprint
      echo msg1.pprint

    assert(dataPacked == dataPacked2)
  except CapnpFormatError:
    discard

runFuzz()
