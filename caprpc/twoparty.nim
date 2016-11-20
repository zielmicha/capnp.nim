## Implements simple two party vat network.
import capnp, caprpc/common, caprpc/twopartyschema, caprpc/msgstream, reactor, caprpc/rpcschema, caprpc/rpc

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

proc bootstrap*(sys: RpcSystem): Cap =
  return sys.bootstrap(VatId(side: Side.server).toAnyPointer)

proc accept*(self: TwoPartyNetwork): Future[Connection] =
  if self.side == Side.server:
    if self.accepted:
      return waitForever(Connection)

    self.accepted = true
    return now(just(self.conn))
  else:
    return waitForever(Connection)

proc connect*(self: TwoPartyNetwork, id: AnyPointer): Connection =
  let side = id.castAs(VatId).side
  if side == self.side:
    raise newException(system.Exception, "cannot connect to self")

  return self.conn

proc newTwoPartyClient*(pipe: BytePipe): RpcSystem =
  let net = newTwoPartyNetwork(pipe, Side.client)
  return newRpcSystem(net.asVatNetwork, nil)

proc newTwoPartyServer*(pipe: BytePipe, myBootstrap: CapServer): RpcSystem =
  let net = newTwoPartyNetwork(pipe, Side.server)
  return newRpcSystem(net.asVatNetwork, myBootstrap)
