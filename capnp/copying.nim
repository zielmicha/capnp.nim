
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
      pointerCount: int
      dataLength: int
    of AnyPointerKind.obj:
      typeIndex: int
      pack: proc(buffer: var string, offset: int)
      unwrap: proc(dest: pointer)

proc castAs*[T](self: AnyPointer, ty: typedesc[T]): T =
  case self.kind:
    of AnyPointerKind.unpacker:
      self.unpacker.currentSegment = self.segment
      return unpackPointer(self.unpacker, self.offset, T)
    of AnyPointerKind.obj:
      if getTypeIndex(T) != self.typeIndex:
        raise newException(Exception, "trying to cast $1 to $2 ($3)" % [$self.typeIndex, $getTypeIndex(T), name(T)])
      self.unwrap(addr result)

proc toAnyPointer*[T](t: T): AnyPointer =
  result.kind = AnyPointerKind.obj
  result.typeIndex = getTypeIndex(T)
  result.unwrap = proc(p: pointer) = (cast[ptr T](p))[] = t
  result.pack = proc(buffer: var string, offset: int) = packPointer(buffer, offset, t)

proc capnpPackStructImpl*(bufferM: var string, value: AnyPointer, dataOffset: int, minDataSize=0): tuple[dataSize: int, pointerCount: int] =
  doAssert(false)

proc capnpUnpackStructImpl*(self: Unpacker, offset: int, dataLength: int, pointerCount: int, typ: typedesc[AnyPointer]): AnyPointer =
  # TODO
  return AnyPointer(kind: AnyPointerKind.unpacker,
                    unpacker: self,
                    segment: self.currentSegment,
                    offset: offset,
                    pointerCount: pointerCount,
                    dataLength: dataLength)
