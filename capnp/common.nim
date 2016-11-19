
type SomeInt = int8|int16|int32|int64|uint8|uint16|uint32|uint64

proc capnpSizeofT*[T: SomeInt|float32|float64](t: typedesc[T]): int =
  sizeof(T)

proc capnpSizeofT*[T: enum](t: typedesc[T]): int =
  sizeof(uint16)

template capnpSizeof*(e): typed =
  capnpSizeofT(type(e))
