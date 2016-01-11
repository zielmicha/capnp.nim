import macros

type PointerFlag* {.pure.} = enum
  none, text

template capnpUnpackScalarMember*(name, fieldOffset, fieldDefault) =
  if offset + fieldOffset + sizeof(result.name) > self.buffer.len:
    result.name = fieldDefault
  else:
    result.name = self.unpackScalar(offset + fieldOffset, type(result.name), fieldDefault)

template capnpUnpackPointerMember*(name, pointerIndex, flag) =
  if pointerIndex < pointerCount:
    let realOffset = offset + pointerIndex * 8 + dataLength
    if realOffset + 8 <= self.buffer.len:
      when flag == PointerFlag.text:
        result.name = self.unpackText(realOffset, type(result.name))
      else:
        result.name = self.unpackPointer(realOffset, type(result.name))

macro makeStructCoders*(typeName, scalars, pointers, bitfields): stmt =
  # capnpUnpackStructImpl is generic to delay instantiation
  result = parseStmt("""proc capnpUnpackStructImpl*[T: XXX](self: Unpacker, offset: int, dataLength: int, pointerCount: int, typ: typedesc[T]): T =
  new(result)""")

  result[0][2][0][1] = typeName # replace XXX
  #result.treeRepr.echo
  var body = result[0][^1]

  for p in scalars:
    let name = p[0].ident
    let offset = p[1]
    let default = p[2]
    body.add(newCall(!"capnpUnpackScalarMember", newIdentNode(name), offset, default))

  for p in pointers:
    let name = p[0].ident
    let offset = p[1]
    let flag = p[2]
    body.add(newCall(!"capnpUnpackPointerMember", newIdentNode(name), offset, flag))

  result.repr.echo
