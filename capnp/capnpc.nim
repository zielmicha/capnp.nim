import capnp, capnp/compiler, capnp/schema

when isMainModule:
  let data = readAll(stdin)
  let req = newUnpacker(data).unpackStruct(0, CodeGeneratorRequest)

  generateCode(req)
