
type
  AnyPointerKind {.pure.} = enum
    unpacker
    obj

  AnyPointer* = ref object of RootObj
    # AnyPointer can be created in two ways: either by unpacking Capnp object or by wrapping a Nim one.
    case kind: AnyPointerKind
    of AnyPointerKind.unpacker:
      unpacker: Unpacker
      segment: int
      offset: int
    of AnyPointerKind.obj:
      typeIndex: int
      pack: proc(buffer: var string, offset: int)
      unwrap: proc(dest: pointer)

var currentTypeIndex {.compiletime.}: int = 1

proc nextTypeIndex(): int {.compiletime.} =
  currentTypeIndex += 1
  return currentTypeIndex

proc getTypeIndex[T](t: typedesc[T]): int =
  result = nextTypeIndex()

proc capnpPackStructImpl*(bufferM: var string, value: AnyPointer, dataOffset: int, minDataSize=0): tuple[dataSize: int, pointerCount: int] =
  doAssert(false)

proc capnpUnpackStructImpl*(self: Unpacker, offset: int, dataLength: int, pointerCount: int, typ: typedesc[AnyPointer]): AnyPointer =
  # TODO
  return nil
