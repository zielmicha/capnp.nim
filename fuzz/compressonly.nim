import capnp, collections
import capnp, caprpc/rpcschema, posix, fuzzlib, collections

proc main() =
  let data = stdin.readAll
  if data.len mod 8 != 0:
    quit 0

  let compressed = compressCapnp(data)
  let v1 = decompressCapnp(compressed)
  when not defined(fuzz):
    echo compressed.encodeHex
  doAssert(data == v1)

runFuzz()
