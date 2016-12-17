import capnp, capnp/gensupport, collections/iface

# file: examples/nested.capnp
from examples/calculator_schema import nil

type
  CalculatorHolder* = ref object
    item*: calculator_schema.Calculator



makeStructCoders(CalculatorHolder, [], [
  (item, 0, PointerFlag.none, true)
  ], [])


