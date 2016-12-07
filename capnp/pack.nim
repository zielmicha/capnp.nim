# included from capnp.nim
when not compiles(isInCapnp): {.error: "do not import this file directly".}
import collections

type Packer* = ref object
  buffer*: string
  capToIndex*: (proc(cap: CapServer): int)

proc packPointer*[T](p: Packer, offset: int, value: T)

proc packScalar*[T: SomeInt](v: var string, offset: int, value: T, defaultValue: T) =
  pack(v, offset, value xor defaultValue)

proc packScalar*(v: var string, offset: int, value: float32, defaultValue: float32) =
  packScalar(v, offset, cast[uint32](value), cast[uint32](defaultValue))

proc packScalar*(v: var string, offset: int, value: float64, defaultValue: float64) =
  packScalar(v, offset, cast[uint64](value), cast[uint64](defaultValue))

proc packScalar*[T: enum](v: var string, offset: int, value: T, defaultValue: T) =
  packScalar(v, offset, cast[uint16](value), cast[uint16](defaultValue))

proc packBool*(v: var string, bitOffset: int, value: bool, defaultValue: bool) =
  let offset = bitOffset div 8
  let bit = bitOffset mod 8
  if value xor defaultValue:
    v[offset] = (v[offset].uint8 or (1 shl bit).uint8).char
  else:
    v[offset] = (v[offset].uint8 and (not (1 shl bit).uint8)).char

proc getSizeTag(s: int): int {.compiletime.} =
  case s:
    of 1: return 2
    of 2: return 3
    of 4: return 4
    of 8: return 5
    else: doAssert(false, "bad size")

proc packScalarList[T, R](p: Packer, offset: int, value: T, typ: typedesc[R]) =
  assert p.buffer != nil
  let bodyOffset = p.buffer.len
  assert bodyOffset mod 8 == 0

  p.buffer.setLen bodyOffset + value.len * sizeof(typ)

  copyMem(addr p.buffer[bodyOffset], unsafeAddr value[0], value.len * sizeof(typ))

  when cpuEndian == bigEndian:
    {.error: "TODO: swap items on list".}

  p.buffer.padWords

  let itemSizeTag = getSizeTag(sizeof(typ))

  let deltaOffset = (bodyOffset - offset - 8) div 8
  pack(p.buffer, offset,
       1.uint64 or
       (deltaOffset.uint64 shl 2) or
       (itemSizeTag.uint64 shl 32) or
       (value.len.uint64 shl 35))

proc packPointerList[R](p: Packer, offset: int, value: seq[R], typ: typedesc[R]) =
  mixin packPointer

  let bodyOffset = p.buffer.len
  assert bodyOffset mod 8 == 0

  p.buffer.setLen bodyOffset + value.len * 8

  for i, item in value:
    packPointer(p, bodyOffset + i * 8, item)

  let itemSizeTag = 6
  let deltaOffset = (bodyOffset - offset - 8) div 8
  pack(p.buffer, offset,
       1.uint64 or
       (deltaOffset.uint64 shl 2) or
       (itemSizeTag.uint64 shl 32) or
       (value.len.uint64 shl 35))

proc packNil(p: Packer, offset: int) =
  if offset + 8 <= p.buffer.len:
    pack(p.buffer, offset, 0.uint64)

proc packCompositeList[R](p: Packer, offset: int, value: seq[R], typ: typedesc[R]) =
  if value.len == 0:
    packNil(p, offset)
    return

  mixin capnpPackStructImpl

  var dataSize = 0
  var pointerCount = 0

  for item in value:
    var fakeBuffer: string = nil
    let info = capnpPackStructImpl(p, fakeBuffer, item, 0)
    dataSize = max(dataSize, info.dataSize)
    pointerCount = max(pointerCount, info.pointerCount)

  let structLength = (dataSize + pointerCount) * 8
  let wordCount = (dataSize + pointerCount) * value.len

  let bodyOffset = p.buffer.len
  p.buffer.add newZeroString(8)
  let dataOffset = p.buffer.len
  p.buffer.add newZeroString(structLength * value.len)

  for i, item in value:
    discard capnpPackStructImpl(p, p.buffer, item, dataOffset + i * structLength, minDataSize=dataSize)

  let deltaOffset = (bodyOffset - offset - 8) div 8
  pack(p.buffer, offset,
       1.uint64 or
       (deltaOffset.uint64 shl 2) or
       (7.uint64 shl 32) or
       (wordCount.uint64 shl 35))

  pack(p.buffer, bodyOffset,
       0.uint64 or
       (value.len.uint64 shl 2) or
       (dataSize.uint64 shl 32) or
       (pointerCount.uint64 shl 48))

proc packListImpl[T, R](p: Packer, offset: int, value: T, typ: typedesc[R]) =
  if value == nil:
    return
  when typ is CapnpScalar:
    packScalarList(p, offset, value, typ)
  elif typ is (seq|string):
    packPointerList(p, offset, value, typ)
  else:
    packCompositeList(p, offset, value, typ)

proc packList*[T](p: Packer, offset: int, value: seq[T]) =
  packListImpl(p, offset, value, T)

proc packList*(p: Packer, offset: int, value: string) =
  packListImpl(p, offset, value, byte)

proc packStruct[T](p: Packer, offset: int, value: T) =
  mixin capnpPackStructImpl

  let dataOffset = p.buffer.len
  let info = capnpPackStructImpl(p, p.buffer, value, dataOffset)
  let deltaOffset = (dataOffset - offset - 8) div 8
  pack(p.buffer, offset,
       (deltaOffset.uint64 shl 2) or
       (info.dataSize.uint64 shl 32) or
       (info.pointerCount.uint64 shl 48))

proc packCap(p: Packer, offset: int, value: CapServer) =
  let id = p.capToIndex(value)
  pack(p.buffer, offset,
       3.uint64 or (id.uint64 shl 32))

proc packPointer*[T](p: Packer, offset: int, value: T) =
  when value is (string|seq):
    packList(p, offset, value)
  elif compiles(toCapServer(value)):
    packCap(p, offset, toCapServer(value))
  else:
    if value.isNil:
      packNil(p, offset)
    else:
      packStruct(p, offset, value)

proc preprocessText(v: string): string =
  if v == nil: return v
  else: return v & "\0"

proc preprocessText[T](v: seq[T]): seq[T] =
  if v == nil:
    return v
  else:
    return v.map(x => preprocessText(x))

proc packText*[T](p: Packer, offset: int, value: T) =
  packPointer(p, offset, preprocessText(value))

proc newPacker*(): Packer =
  let capToIndex = proc(cap: CapServer): int =
    raise newException(Exception, "this packer doesn't support capabilities")

  return Packer(
    buffer: newZeroString(8),
    capToIndex: capToIndex)

proc packPointer*[T](value: T): string =
  let packer = newPacker()
  packPointer(packer, 0, value)
  return packer.buffer
