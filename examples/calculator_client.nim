import reactor, capnp, caprpc, calculator_schema



proc main() {.async.} =
  echo "connecting"
  let sys = newTwoPartyClient(await connectTcp("127.0.0.1:7890")) # localhost:6789
  echo "ok"

  discard createFromCap(Calculator_Value, CapServer(Interface()))
  discard createFromCap(Calculator, CapServer(Interface()))

  let calculator = await sys.bootstrap().castAs(Calculator)

  let addOp = await calculator.getOperator(Calculator_Operator.add)
  let myExpr = Calculator_Expression(kind: Calculator_ExpressionKind.call,
                                     function: addOp,
                                     params: @[
                                       Calculator_Expression(kind: Calculator_ExpressionKind.literal, literal: 1),
                                       Calculator_Expression(kind: Calculator_ExpressionKind.literal, literal: 2)])
  let ret = await calculator.evaluate(myExpr)
  let retb = await ret.read()
  echo(retb)

  let myFunc = inlineCap(Calculator_Function, Calculator_FunctionInlineImpl(
    call: proc(params: seq[float64]): Future[float64] =
              echo "called!"
              return now(just(666.0 + params[0]))
  ))

  let expr2 = Calculator_Expression(kind: Calculator_ExpressionKind.call,
                                     function: myFunc,
                                     params: @[
                                       Calculator_Expression(kind: Calculator_ExpressionKind.literal, literal: 1)])
  let ret1 = await calculator.evaluate(expr2)
  let ret1b = await ret1.read()
  echo(ret1b)

  discard (await calculator.getOperator(Calculator_Operator.subtract))
  echo "collecting garbage..."
  GC_fullCollect()

when isMainModule:
  main().runMain()
  GC_fullCollect()
