## Implements simple two party vat network.
import capnp, caprpc/common, caprpc/twopartyschema, caprpc/msgstream, reactor, caprpc/rpcschema

type
  TwoPartyNetwork* = ref object of RootObj
    conn: Connection
    accepted: bool
    side: Side

proc newTwoParyNetwork*(pipe: BytePipe, side: Side): TwoPartyNetwork =
  new(result)
  result.side = side
  let msgPipe = msgstream.wrapBytePipe(pipe, rpcschema.Message)
  result.conn = Connection(input: msgPipe.input, output: msgPipe.output)

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
