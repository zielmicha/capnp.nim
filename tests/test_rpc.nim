import reactor, capnp
import caprpc/msgstream, caprpc/rpcschema, caprpc/twoparty

proc main() {.async.} =
  let sys = newTwoPartyClient(await connectTcp("10.234.0.1:901")) # localhost:6789
  let obj = sys.bootstrap()

  await waitForever()

when isMainModule:
  main().runMain

