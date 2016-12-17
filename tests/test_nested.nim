import examples/nested_schema, examples/calculator_schema, caprpc

let r = pack(CalculatorHolder(item: Calculator.createFromCap(nothingImplemented)))
