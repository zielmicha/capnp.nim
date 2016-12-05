import reactor, capnp, caprpc, simplerpc_schema, collections/pprint, collections/iface

proc main() {.async.} =
  let sys = newTwoPartyClient(await connectTcp("127.0.0.1:6789")) # localhost:6789
  let obj = await sys.bootstrap()

  echo(await obj.castAs(SimpleRpc).identity(15))

  let obj1 = obj # await sys.bootstrap()
  echo(await obj1.castAs(SimpleRpc).identity(16))

when isMainModule:
  main().runMain()
