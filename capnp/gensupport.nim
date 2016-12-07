import macros, strutils, capnp, collections

type PointerFlag* {.pure.} = enum
  none, text

template kindMatches(obj, v): typed =
  assert obj != nil
  when v is bool:
    v
  else:
    obj.kind == v

template capnpUnpackScalarMember*(name, fieldOffset, fieldDefault, condition) =
  if kindMatches(result, condition):
    if fieldOffset + sizeof(name) > dataLength:
      name = fieldDefault
    else:
      name = self.unpackScalar(offset + fieldOffset, type(name), fieldDefault)

template capnpUnpackBoolMember*(name, fieldOffset, fieldDefault, condition) =
  if kindMatches(result, condition):
    if fieldOffset div 8 >= dataLength:
      name = fieldDefault
    else:
      name = self.unpackBool(offset, fieldOffset, defaultValue=fieldDefault)

template capnpPackScalarMember*(name, fieldOffset, fieldDefault, condition) =
  if kindMatches(value, condition):
    packScalar(scalarBuffer, fieldOffset, name, fieldDefault)

template capnpPackBoolMember*(name, fieldOffset, fieldDefault, condition) =
  if kindMatches(value, condition):
    packBool(scalarBuffer, fieldOffset, name, fieldDefault)

template capnpUnpackPointerMember*(name, pointerIndex, flag, condition) =
  if kindMatches(result, condition):
    name = defaultVal(type(name))
    if pointerIndex < pointerCount:
      let realOffset = offset + pointerIndex * 8 + dataLength
      if realOffset + 8 <= buffer(self).len:
        when flag == PointerFlag.text:
          name = unpackText(self, realOffset, type(name))
        else:
          name = unpackPointer(self, realOffset, type(name))

template capnpPreparePack*() =
  trimWords(scalarBuffer, minDataSize * 8)
  if bufferM != nil:
    bufferM.insertAt(dataOffset, scalarBuffer)
  var pointers {.inject.}: seq[bool] = @[]

template capnpPreparePackPointer*(name, offset, condition) =
  if kindMatches(value, condition):
    if not isNil(name) and pointers.len <= offset:
      pointers.setLen offset + 1

template capnpPreparePackFinish*() =
  let pointerOffset {.inject.} = dataOffset + scalarBuffer.len
  if bufferM != nil:
    bufferM.insertAt(pointerOffset, newZeroString(pointers.len * 8))

template capnpPackPointer*(name, offset, flag, condition): untyped =
  if bufferM != nil and kindMatches(value, condition) and not isNil(name):
    when flag == PointerFlag.text:
      packText(p, pointerOffset + offset * 8, name)
    else:
      packPointer(p, pointerOffset + offset * 8, name)

template capnpPackFinish*(): untyped =
  assert((scalarBuffer.len mod 8) == 0, "")
  return (tuple[dataSize: int, pointerCount: int])((scalarBuffer.len div 8, pointers.len))

proc newComplexDotExpr(a: NimNode, b: NimNode): NimNode {.compileTime.} =
  var b = b
  var a = a
  while b.kind == nnkDotExpr:
    a = newDotExpr(a, b[0])
    b = b[1]
  return newDotExpr(a, b)

proc makeUnpacker(typename: NimNode, scalars: NimNode, pointers: NimNode, bools: NimNode): NimNode {.compiletime.} =
  # capnpUnpackStructImpl is generic to delay instantation
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

  for p in bools:
    let name = p[0]
    let offset = p[1]
    let default = p[2]
    let condition = p[3]
    body.add(newCall(!"capnpUnpackBoolMember", newComplexDotExpr(resultId, name), offset, default, condition))

  for p in pointers:
    let name = p[0]
    let offset = p[1]
    let flag = p[2]
    let condition = p[3]
    body.add(newCall(!"capnpUnpackPointerMember", newComplexDotExpr(resultId, name), offset, flag, condition))

proc makePacker(typename: NimNode, scalars: NimNode, pointers: NimNode, bools: NimNode): NimNode {.compiletime.} =
  # bufferM should be named buffer, but compiler manages to confuse it with buffer proc in unpack
  result = parseStmt("""proc capnpPackStructImpl*[T: XXX](p: Packer, bufferM: var string, value: T, dataOffset: int, minDataSize=0): tuple[dataSize: int, pointerCount: int] =
  var scalarBuffer = newZeroString(max(@[0]))""")

  result[0][2][0][1] = typeName # replace XXX
  let body = result[0][6]
  let sizesList = body[0][0][2][1][1][1]
  let valueId = newIdentNode($"value")

  for p in scalars:
    let name = p[0]
    let offset = p[1]
    sizesList.add(newCall(newIdentNode($"+"),  newCall(newIdentNode($"capnpSizeof"), newComplexDotExpr(valueId, name)), offset))

  for p in bools:
    let offset = p[1]
    sizesList.add(newLit((offset.intVal + 8) div 8))

  for p in scalars:
    let name = p[0]
    let offset = p[1]
    let default = p[2]
    let condition = p[3]

    body.add(newCall(!"capnpPackScalarMember", newComplexDotExpr(valueId, name), offset, default, condition))

  for p in bools:
    let name = p[0]
    let offset = p[1]
    let default = p[2]
    let condition = p[3]

    body.add(newCall(!"capnpPackBoolMember", newComplexDotExpr(valueId, name), offset, default, condition))

  body.add(newCall(!"capnpPreparePack"))

  for p in pointers:
    let name = p[0]
    let offset = p[1]
    let condition = p[3]

    body.add(newCall(!"capnpPreparePackPointer", newComplexDotExpr(valueId, name), offset, condition))

  body.add(newCall(!"capnpPreparePackFinish"))

  for p in pointers:
    let name = p[0]
    let offset = p[1]
    let flag = p[2]
    let condition = p[3]

    body.add(newCall(!"capnpPackPointer", newComplexDotExpr(valueId, name), offset, flag, condition))

  body.add(parseStmt("capnpPackFinish()"))

macro makeStructCoders*(typeName, scalars, pointers, bitfields): untyped =
  newNimNode(nnkStmtList)
    .add(makeUnpacker(typeName, scalars, pointers, bitfields))
    .add(makePacker(typeName, scalars, pointers, bitfields))
