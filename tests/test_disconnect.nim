import caprpc, capnp, reactor

type MyCap = ref object of RootRef

proc call(self: MyCap, ifaceId: uint64, methodId: uint64, args: AnyPointer): Future[AnyPointer] {.async.} =
  await waitForever()

asyncMain:
  let (comm1, comm2) = newPipe(byte)
  discard newTwoPartyServer(comm1, MyCap().asCapServer)
  let client = newTwoPartyClient(comm2)
  let mycap = await client.bootstrap().castAs(CapServer)

  proc check() {.async.} =
    discard await mycap.call(0.uint64, 0.uint64, ("hello").toAnyPointer)

  let f = check()
  comm1.close(JustClose)
  await f
