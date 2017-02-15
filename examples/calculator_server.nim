import reactor, capnp, caprpc, calculator_schema

type MyCalculator = ref object of RootObj

proc evaluate(self: MyCalculator, expression: Calculator_Expression): Future[Calculator_Value] =
  return now(error(Calculator_Value, "not implemented"))

proc defFunction(self: MyCalculator, paramCount: int32, body: Calculator_Expression): Future[Calculator_Function] =
  return now(error(Calculator_Function, "not implemented"))

proc getOperator(self: MyCalculator, op: Calculator_Operator): Future[Calculator_Function] =
  return now(error(Calculator_Function, "not implemented"))

proc toCapServer(self: MyCalculator): CapServer =
  return toGenericCapServer(self.asCalculator)

proc main() {.async.} =
  # let sys = newTwoPartyClient(await connectTcp("127.0.0.1:7890")) # localhost:6789
  let server = await createTcpServer(7890)

  let myCalculator = new(MyCalculator)

  echo "waiting for incoming connections"
  asyncFor conn in server.incomingConnections:
    echo "connection received"
    discard newTwoPartyServer(conn.BytePipe, myCalculator.toCapServer)

when isMainModule:
  main().runMain()
