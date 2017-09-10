import capnp, caprpc/rpcschema, posix, fuzzlib, collections

proc main() =
  let packer = newPacker()
  let data = stdin.readAll

  try:
    let u = newUnpacker(data)
    copyPointer(u, 0, packer, 0)
  except CapnpFormatError:
    return

  let msg1 = packer.buffer

  when not defined(fuzz):
    echo data.encodeHex
    echo msg1.encodeHex

  let packer2 = newPacker()
  let u1 = newUnpackerFlat(msg1)
  copyPointer(u1, 0, packer2, 0)
  let msg2 = packer2.buffer

  when not defined(fuzz):
    echo msg2.encodeHex

  doAssert(msg1 == msg2)

runFuzz()
