import capnp

let data = stdin.readAll
let v = decompressCapnp(data)
let compressed = compressCapnp(v)
let v1 = decompressCapnp(compressed)
doAssert(v == v1)
