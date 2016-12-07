import reactor, capnp, caprpc, calculator_schema



proc main() {.async.} =
  let sys = newTwoPartyClient(await connectTcp("127.0.0.1:7890")) # localhost:6789

  discard createFromCap(Calculator_Value, CapServer(Interface()))
  discard createFromCap(Calculator, CapServer(Interface()))

  let calculator = await sys.bootstrap().castAs(Calculator)

  let addOp = await calculator.getOperator(Calculator_Operator.add)
  let myExpr = Calculator_Expression(kind: Calculator_ExpressionKind.call,
                                     function: addOp,
                                     params: @[])
  let ret = await calculator.evaluate(myExpr)

when isMainModule:
  main().runMain()
