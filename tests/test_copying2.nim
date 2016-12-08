import examples/persondef, capnp, collections, examples/calculator_schema, caprpc

let expr = Calculator_Expression(kind: Calculator_ExpressionKind.call,
                                 function: Calculator_Function.createFromCap(nothingImplemented),
                                 params: @[
                                   Calculator_Expression(kind: Calculator_ExpressionKind.literal, literal: 1),
                                   Calculator_Expression(kind: Calculator_ExpressionKind.literal, literal: 2)])

let params = Calculator_evaluate_Params(expression: expr)

let p = newPacker()
p.capToIndex = proc(c: CapServer): int = return 0
p.packPointer(0, params)
let packed = p.buffer
echo packed.encodeHex

proc makeUnpacker(buffer: string): Unpacker =
  result = newUnpackerFlat(buffer)
  result.getCap = proc(i: int): CapServer =
                      echo "unpack cap ", i
                      return nothingImplemented

discard makeUnpacker(packed).unpackPointer(0, type(params))

let packer1 = newPacker()
copyPointer(newUnpackerFlat(packed), 0, packer1, 0)

echo packer1.buffer.encodeHex

let params_ptr = params.toAnyPointer
let packer2 = newPacker()
packer2.buffer &= newZeroString(8)
copyPointer(newUnpackerFlat(packed), 0, packer2, 8)

assert packer2.buffer[8..^1] == packer1.buffer
