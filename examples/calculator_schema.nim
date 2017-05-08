import capnp, capnp/gensupport, collections/iface

import reactor, caprpc, caprpc/rpcgensupport
# file: examples/calculator.capnp

type
  Calculator* = distinct Interface
  Calculator_CallWrapper* = ref object of CapServerWrapper

  Calculator_ExpressionKind* {.pure.} = enum
    literal = 0, previousResult = 1, parameter = 2, call = 3

  Calculator_Expression* = ref object
    case kind*: Calculator_ExpressionKind:
    of Calculator_ExpressionKind.literal:
      literal*: float64
    of Calculator_ExpressionKind.previousResult:
      previousResult*: Calculator_Value
    of Calculator_ExpressionKind.parameter:
      parameter*: uint32
    of Calculator_ExpressionKind.call:
      function*: Calculator_Function
      params*: seq[Calculator_Expression]

  Calculator_Value* = distinct Interface
  Calculator_Value_CallWrapper* = ref object of CapServerWrapper

  Calculator_Value_read_Params* = ref object

  Calculator_Value_read_Result* = ref object
    value*: float64

  Calculator_Function* = distinct Interface
  Calculator_Function_CallWrapper* = ref object of CapServerWrapper

  Calculator_Function_call_Params* = ref object
    params*: seq[float64]

  Calculator_Function_call_Result* = ref object
    value*: float64

  Calculator_Operator* {.pure.} = enum
    add = 0, subtract = 1, multiply = 2, divide = 3

  Calculator_evaluate_Params* = ref object
    expression*: Calculator_Expression

  Calculator_evaluate_Result* = ref object
    value*: Calculator_Value

  Calculator_defFunction_Params* = ref object
    paramCount*: int32
    body*: Calculator_Expression

  Calculator_defFunction_Result* = ref object
    `func`*: Calculator_Function

  Calculator_getOperator_Params* = ref object
    op*: Calculator_Operator

  Calculator_getOperator_Result* = ref object
    `func`*: Calculator_Function



interfaceMethods Calculator:
  toCapServer(): CapServer
  evaluate(expression: Calculator_Expression): Future[Calculator_Value]
  defFunction(paramCount: int32, body: Calculator_Expression): Future[Calculator_Function]
  getOperator(op: Calculator_Operator): Future[Calculator_Function]

proc getInterfaceId*(t: typedesc[Calculator]): uint64 = return 10923537602090224694'u64

miscCapMethods(Calculator, Calculator_CallWrapper)

proc capCall*[T: Calculator](cap: T, id: uint64, args: AnyPointer): Future[AnyPointer] =
  case int(id):
    of 0:
      let argObj = args.castAs(Calculator_evaluate_Params)
      let retVal = cap.evaluate(argObj.expression)
      return wrapFutureInSinglePointer(Calculator_evaluate_Result, value, retVal)
    of 1:
      let argObj = args.castAs(Calculator_defFunction_Params)
      let retVal = cap.defFunction(argObj.paramCount, argObj.body)
      return wrapFutureInSinglePointer(Calculator_defFunction_Result, `func`, retVal)
    of 2:
      let argObj = args.castAs(Calculator_getOperator_Params)
      let retVal = cap.getOperator(argObj.op)
      return wrapFutureInSinglePointer(Calculator_getOperator_Result, `func`, retVal)
    else: raise newException(NotImplementedError, "not implemented")

proc evaluate*[T: Calculator_CallWrapper](self: T, expression: Calculator_Expression): Future[Calculator_Value] =
  return getFutureField(self.cap.call(10923537602090224694'u64, 0, toAnyPointer(Calculator_evaluate_Params(expression: expression))).castAs(Calculator_evaluate_Result), value)

proc defFunction*[T: Calculator_CallWrapper](self: T, paramCount: int32, body: Calculator_Expression): Future[Calculator_Function] =
  return getFutureField(self.cap.call(10923537602090224694'u64, 1, toAnyPointer(Calculator_defFunction_Params(paramCount: paramCount, body: body))).castAs(Calculator_defFunction_Result), `func`)

proc getOperator*[T: Calculator_CallWrapper](self: T, op: Calculator_Operator): Future[Calculator_Function] =
  return getFutureField(self.cap.call(10923537602090224694'u64, 2, toAnyPointer(Calculator_getOperator_Params(op: op))).castAs(Calculator_getOperator_Result), `func`)

makeStructCoders(Calculator_Expression, [
  (kind, 8, low(Calculator_ExpressionKind), true),
  (literal, 0, 0.0, Calculator_ExpressionKind.literal),
  (parameter, 0, 0, Calculator_ExpressionKind.parameter)
  ], [
  (previousResult, 0, PointerFlag.none, Calculator_ExpressionKind.previousResult),
  (function, 0, PointerFlag.none, Calculator_ExpressionKind.call),
  (params, 1, PointerFlag.none, Calculator_ExpressionKind.call)
  ], [])

interfaceMethods Calculator_Value:
  toCapServer(): CapServer
  read(): Future[float64]

proc getInterfaceId*(t: typedesc[Calculator_Value]): uint64 = return 14116142932258867410'u64

miscCapMethods(Calculator_Value, Calculator_Value_CallWrapper)

proc capCall*[T: Calculator_Value](cap: T, id: uint64, args: AnyPointer): Future[AnyPointer] =
  case int(id):
    of 0:
      let argObj = args.castAs(Calculator_Value_read_Params)
      let retVal = cap.read()
      return wrapFutureInSinglePointer(Calculator_Value_read_Result, value, retVal)
    else: raise newException(NotImplementedError, "not implemented")

proc read*[T: Calculator_Value_CallWrapper](self: T, ): Future[float64] =
  return getFutureField(self.cap.call(14116142932258867410'u64, 0, toAnyPointer(Calculator_Value_read_Params())).castAs(Calculator_Value_read_Result), value)

makeStructCoders(Calculator_Value_read_Params, [], [], [])

makeStructCoders(Calculator_Value_read_Result, [
  (value, 0, 0.0, true)
  ], [], [])

interfaceMethods Calculator_Function:
  toCapServer(): CapServer
  call(params: seq[float64]): Future[float64]

proc getInterfaceId*(t: typedesc[Calculator_Function]): uint64 = return 17143016017778443156'u64

miscCapMethods(Calculator_Function, Calculator_Function_CallWrapper)

proc capCall*[T: Calculator_Function](cap: T, id: uint64, args: AnyPointer): Future[AnyPointer] =
  case int(id):
    of 0:
      let argObj = args.castAs(Calculator_Function_call_Params)
      let retVal = cap.call(argObj.params)
      return wrapFutureInSinglePointer(Calculator_Function_call_Result, value, retVal)
    else: raise newException(NotImplementedError, "not implemented")

proc call*[T: Calculator_Function_CallWrapper](self: T, params: seq[float64]): Future[float64] =
  return getFutureField(self.cap.call(17143016017778443156'u64, 0, toAnyPointer(Calculator_Function_call_Params(params: params))).castAs(Calculator_Function_call_Result), value)

makeStructCoders(Calculator_Function_call_Params, [], [
  (params, 0, PointerFlag.none, true)
  ], [])

makeStructCoders(Calculator_Function_call_Result, [
  (value, 0, 0.0, true)
  ], [], [])

makeStructCoders(Calculator_evaluate_Params, [], [
  (expression, 0, PointerFlag.none, true)
  ], [])

makeStructCoders(Calculator_evaluate_Result, [], [
  (value, 0, PointerFlag.none, true)
  ], [])

makeStructCoders(Calculator_defFunction_Params, [
  (paramCount, 0, 0, true)
  ], [
  (body, 0, PointerFlag.none, true)
  ], [])

makeStructCoders(Calculator_defFunction_Result, [], [
  (`func`, 0, PointerFlag.none, true)
  ], [])

makeStructCoders(Calculator_getOperator_Params, [
  (op, 0, Calculator_Operator(0), true)
  ], [], [])

makeStructCoders(Calculator_getOperator_Result, [], [
  (`func`, 0, PointerFlag.none, true)
  ], [])


