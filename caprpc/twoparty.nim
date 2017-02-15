## Implements simple two party vat network.
import capnp, caprpc/common, caprpc/twopartyschema, caprpc/msgstream, reactor, caprpc/rpcschema, caprpc/rpc

export Side

type
  TwoPartyNetwork* = ref object of RootObj
    conn: Connection
    accepted: bool
    side: Side

proc newTwoPartyNetwork*(pipe: BytePipe, side: Side): TwoPartyNetwork =
  new(result)
  result.side = side
  let msgPipe = msgstream.wrapBytePipe(pipe, rpcschema.Message)
  result.conn = Connection(input: msgPipe.input, output: msgPipe.output)

proc bootstrap*(sys: RpcSystem): Future[AnyPointer] =
  return sys.bootstrap("server")

proc accept*(self: TwoPartyNetwork): Future[Connection] =
  if self.side == Side.server:
    if self.accepted:
      return waitForever(Connection)

    self.accepted = true
    return now(just(self.conn))
  else:
    return waitForever(Connection)

proc vatIdToPointer*(self: TwoPartyNetwork, id: common.VatId): AnyPointer =
  if id == "server":
    return twopartyschema.VatId(side: Side.server).toAnyPointer
  else:
    return twopartyschema.VatId(side: Side.client).toAnyPointer

proc vatIdFromPointer*(self: TwoPartyNetwork, id: AnyPointer): common.VatId =
  if id.castAs(twopartyschema.VatId).side == Side.server:
    return "server"
  else:
    return "client"

proc connect*(self: TwoPartyNetwork, id: common.VatId): Connection =
  let side = self.vatIdToPointer(id).castAs(twopartyschema.VatId).side
  if side == self.side:
    raise newException(system.Exception, "cannot connect to self")

  return self.conn

proc newTwoPartyClient*(pipe: BytePipe): RpcSystem =
  let net = newTwoPartyNetwork(pipe, Side.client)
  return newRpcSystem(net.asVatNetwork)

proc newTwoPartyServer*(pipe: BytePipe, myBootstrap: CapServer): RpcSystem =
  let net = newTwoPartyNetwork(pipe, Side.server)
  let system = newRpcSystem(net.asVatNetwork, myBootstrap)
  system.initConnection("client") # start listener
  return system
