import capnp/unpack, capnp/schema, capnp/compiler

when isMainModule:
  let data = readAll(stdin)
  let req = newUnpacker(data).unpackStruct(0, CodeGeneratorRequest)

  generateCode(req)
