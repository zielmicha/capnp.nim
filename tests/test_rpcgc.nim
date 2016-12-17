import caprpc, examples/calculator_schema, reactor

proc main() {.async.} =
  let sys = newTwoPartyClient(await connectTcp("127.0.0.1:7890")) # localhost:6789

  let calculator = await sys.bootstrap().castAs(Calculator)

  let addOp = await calculator.getOperator(Calculator_Operator.add)
  let myExpr = Calculator_Expression(kind: Calculator_ExpressionKind.call,
                                     function: addOp,
                                     params: @[
                                       Calculator_Expression(kind: Calculator_ExpressionKind.literal, literal: 1),
                                       Calculator_Expression(kind: Calculator_ExpressionKind.literal, literal: 2)])

  for i in 1..66:
    discard (await calculator.evaluate(myExpr))
    GC_fullCollect()

when isMainModule:
  main().runMain()
