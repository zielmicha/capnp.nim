import capnp/util

type SomeInt = int8|int16|int32|int64|uint8|uint16|uint32|uint64

proc capnpSizeof*[T: SomeInt|float32|float64](t: T): int=
  sizeof(T)

proc capnpSizeof*[T: enum](t: T): int=
  sizeof(uint16)

proc packScalar*[T: SomeInt](v: var string, offset: int, value: T, defaultValue: T) =
  pack(v, offset, value xor defaultValue)

proc packScalar*(v: var string, offset: int, value: float32, defaultValue: float32) =
  packScalar(v, offset, cast[uint32](value), cast[uint32](defaultValue))

proc packScalar*(v: var string, offset: int, value: float64, defaultValue: float64) =
  packScalar(v, offset, cast[uint64](value), cast[uint64](defaultValue))

proc packScalar*[T: enum](v: var string, offset: int, value: T, defaultValue: T) =
  packScalar(v, offset, cast[uint16](value), cast[uint16](defaultValue))

proc getSizeTag(s: int): int {.compiletime.} =
  case s:
    of 1: return 2
    of 2: return 3
    of 4: return 4
    of 8: return 5
    else: doAssert(false, "bad size")

proc packListScalar[T, R](buffer: var string, offset: int, value: T, typ: typedesc[R]) =
  let bodyOffset = buffer.len
  assert bodyOffset mod 8 == 0

  buffer.setLen bodyOffset + value.len * sizeof(typ)

  copyMem(addr buffer[bodyOffset], unsafeAddr value[0], value.len * sizeof(typ))

  buffer.padWords

  let itemSizeTag = getSizeTag(sizeof(typ))

  let deltaOffset = (bodyOffset - offset - 8) div 8
  pack(buffer, offset,
       1.uint64 or
       (deltaOffset.uint64 shl 2) or
       (itemSizeTag.uint64 shl 32) or
       (value.len.uint64 shl 35))

proc packCompositeList[R](buffer: var string, offset: int, value: seq[R], typ: typedesc[R]) =
  mixin capnpPackStructImpl

  var dataSize = 0
  var pointerCount = 0

  for item in value:
    var fakeBuffer: string = nil
    let info = capnpPackStructImpl(fakeBuffer, item, 0)
    dataSize = max(dataSize, info.dataSize)
    pointerCount = max(pointerCount, info.pointerCount)

  let structLength = (dataSize + pointerCount) * 8
  let wordCount = (dataSize + pointerCount) * value.len

  let bodyOffset = buffer.len
  buffer.add newZeroString(8)
  let dataOffset = buffer.len
  buffer.add newZeroString(structLength * value.len)

  for i, item in value:
    let beforeOffset = buffer.len
    discard capnpPackStructImpl(buffer, item, dataOffset + i * structLength, minDataSize=dataSize)

  let deltaOffset = (bodyOffset - offset - 8) div 8
  pack(buffer, offset,
       1.uint64 or
       (deltaOffset.uint64 shl 2) or
       (7.uint64 shl 32) or
       (wordCount.uint64 shl 35))

  pack(buffer, bodyOffset,
       0.uint64 or
       (value.len.uint64 shl 2) or
       (dataSize.uint64 shl 32) or
       (pointerCount.uint64 shl 48))

proc packListImpl[T, R](buffer: var string, offset: int, value: T, typ: typedesc[R]) =
  if value == nil:
    return
  when typ is CapnpScalar:
    packListScalar(buffer, offset, value, typ)
  else:
    packCompositeList(buffer, offset, value, typ)

proc packList*[T](buffer: var string, offset: int, value: seq[T]) =
  packListImpl(buffer, offset, value, T)

proc packList*(buffer: var string, offset: int, value: string) =
  packListImpl(buffer, offset, value, byte)

proc packStruct*[T](buffer: var string, offset: int, value: T) =
  mixin capnpPackStructImpl

  let dataOffset = buffer.len
  let info = capnpPackStructImpl(buffer, value, dataOffset)
  let deltaOffset = (dataOffset - offset - 8) div 8
  pack(buffer, offset,
       (deltaOffset.uint64 shl 2) or
       (info.dataSize.uint64 shl 32) or
       (info.pointerCount.uint64 shl 48))

proc packPointer*[T](buffer: var string, offset: int, value: T) =
  when value is (string|seq):
    packList(buffer, offset, value)
  else:
    packStruct(buffer, offset, value)

proc packText*(buffer: var string, offset: int, value: string) =
  if value == nil:
    packPointer(buffer, offset, value)
  else:
    packPointer(buffer, offset, value & "\0")

proc packStruct*[T](value: T): string =
  result = newZeroString(8)
  packStruct(result, 0, value)
