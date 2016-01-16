import capnp/util

type SomeInt = int8|int16|int32|int64|uint8|uint16|uint32|uint64

proc packScalar*[T: SomeInt](v: var string, offset: int, value: T, defaultValue: T) =
  pack(v, offset, value xor defaultValue)

proc packScalar*(v: var string, offset: int, value: float32, defaultValue: float32) =
  packScalar(v, offset, cast[uint32](value), cast[uint32](defaultValue))

proc packScalar*(v: var string, offset: int, value: float64, defaultValue: float64) =
  packScalar(v, offset, cast[uint64](value), cast[uint64](defaultValue))

proc packListImpl[T, R](buffer: var string, offset: int, value: T, typ: typedesc[R]) =
  discard

proc packList*[T](buffer: var string, offset: int, value: seq[T]) =
  packListImpl(buffer, offset, value, T)

proc packList*(buffer: var string, offset: int, value: string) =
  packListImpl(buffer, offset, value, char)

proc packStruct*[T](buffer: var string, offset: int, value: T) =
  mixin capnpPackStructImpl

  let dataOffset = buffer.len
  let info = capnpPackStructImpl(buffer, value)
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
