import reactor, capnp
import caprpc/msgstream
import caprpc/rpcschema

proc main() {.async.} =
  let server = await createTcpServer(901)
  asyncFor conn in server.incomingConnections:
    asyncFor msg in msgstream.wrapStream(conn.input, Message):
      echo msg.repr

when isMainModule:
  main().runMain
