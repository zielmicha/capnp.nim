import examples/calculator_schema, caprpc, reactor

type MyFunc = ref object of RootRef

proc call(self: MyFunc, data: seq[float64]): Future[float64] =
  return now(just(data[0]))

capServerImpl(MyFunc, [Calculator_Function])
