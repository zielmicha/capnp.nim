import capnp/schema, capnp/unpack

when isMainModule:
  let data = readAll(stdin)
  let n = newUnpacker(data).unpackStruct(0, CodeGeneratorRequest)
  echo n.repr
