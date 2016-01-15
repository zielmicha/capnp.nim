import macros

type PointerFlag* {.pure.} = enum
  none, text

template capnpUnpackScalarMember*(name, fieldOffset, fieldDefault, condition) =
  if condition:
    if offset + fieldOffset + sizeof(name) > self.buffer.len:
      name = fieldDefault
    else:
      name = self.unpackScalar(offset + fieldOffset, type(name), fieldDefault)

template capnpUnpackPointerMember*(name, pointerIndex, flag, condition) =
  if condition:
    name = nil
    if pointerIndex < pointerCount:
      let realOffset = offset + pointerIndex * 8 + dataLength
      if realOffset + 8 <= self.buffer.len:
        when flag == PointerFlag.text:
          name = self.unpackText(realOffset, type(name))
        else:
          name = self.unpackPointer(realOffset, type(name))

proc newComplexDotExpr(a: NimNode, b: NimNode): NimNode {.compileTime.} =
  var b = b
  var a = a
  while b.kind == nnkDotExpr:
    a = newDotExpr(a, b[0])
    b = b[1]
  return newDotExpr(a, b)

macro makeStructCoders*(typeName, scalars, pointers, bitfields): stmt =
  # capnpUnpackStructImpl is generic to delay instantiation
  result = parseStmt("""proc capnpUnpackStructImpl*[T: XXX](self: Unpacker, offset: int, dataLength: int, pointerCount: int, typ: typedesc[T]): T =
  new(result)""")

  result[0][2][0][1] = typeName # replace XXX
  #result.treeRepr.echo
  var body = result[0][^1]
  let resultId = newIdentNode($"result")

  for p in scalars:
    let name = p[0]
    let offset = p[1]
    let default = p[2]
    let condition = p[3]
    body.add(newCall(!"capnpUnpackScalarMember", newComplexDotExpr(resultId, name), offset, default, condition))

  for p in pointers:
    let name = p[0]
    let offset = p[1]
    let flag = p[2]
    let condition = p[3]
    body.add(newCall(!"capnpUnpackPointerMember", newComplexDotExpr(resultId, name), offset, flag, condition))

  result.repr.echo
