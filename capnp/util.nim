when not compiles(isInCapnp): {.error: "do not import this file directly".}
import endians, strutils, sequtils, typetraits, collections/reflect, collections/lang, collections/iface, collections/pprint

type CapnpFormatError* = object of Exception

type CapnpScalar* = uint8 | uint16 | uint32 | uint64 | int8 | int16 | int32 | int64 | float32 | float64 | byte | char | enum

proc convertEndian*(size: static[int], dst: pointer, src: pointer, endian=littleEndian) {.inline.} =
  when size == 1:
    copyMem(dst, src, 1)
  else:
    case endian:
    of bigEndian:
      when size == 2:
        bigEndian16(dst, src)
      elif size == 4:
        bigEndian32(dst, src)
      elif size == 8:
        bigEndian64(dst, src)
      else:
        {.error: "Unsupported size".}
    of littleEndian:
      when size == 2:
        littleEndian16(dst, src)
      elif size == 4:
        littleEndian32(dst, src)
      elif size == 8:
        littleEndian64(dst, src)
      else:
        {.error: "Unsupported size".}

proc pack*[T](v: var string, offset: int, value: T, endian=littleEndian) {.inline.} =
  let minLength = offset + sizeof(T)
  if minLength > v.len:
    raise newException(CapnpFormatError, "bad offset")

  convertEndian(sizeof(T), addr v[offset], unsafeAddr value)

proc pack*[T](value: T, endian=littleEndian): string {.inline.} =
  var s = newString(sizeof(T))
  pack(s, 0, value, endian)
  return s

proc unpack*[T](v: string, offset: int, t: typedesc[T], endian=littleEndian): T {.inline.} =
  if not (offset < v.len and offset + sizeof(t) <= v.len and offset >= 0):
    raise newException(CapnpFormatError, "bad offset (offset=$1 len=$2)" % [$offset, $v.len])

  convertEndian(sizeof(T), addr result, unsafeAddr v[offset])

proc extractBits*(v: uint64|uint32|uint16|uint8, k: Natural, bits: int): int {.inline.} =
  assert k + bits <= sizeof(v) * 8
  return cast[int]((v shr k) and ((1 shl bits) - 1).uint64)

proc newZeroString*(length: int): string =
  repeat('\0', length)

proc isZeros(s: string): bool =
  for i in s:
    if i != '\0': return false
  return true

proc padWords*(s: var string) =
  if s.len mod 8 != 0:
    s &= newZeroString(8 - (s.len mod 8))

proc trimWords*(s: var string, minSize=0) =
  while s.len > minSize:
    let offset = ((s.len - 1) div 8) * 8
    let trailing = s[offset..^1]
    if isZeros(trailing):
      s.setLen(offset)
    else:
      break

  s.padWords
  if s.len < minSize * 8:
    s &= newZeroString(minSize - s.len)

proc insertAt*(s: var string, offset: int, data: string) =
  assert s != nil

  if offset < 0:
    raise newException(IndexError, "offset < 0")
  if s.len < offset + data.len:
    s.setLen offset + data.len

  copyMem(addr s[offset], unsafeAddr data[0], data.len)
