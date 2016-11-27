
type
  AnyPointerKind {.pure.} = enum
    unpacker
    obj

  AnyPointerImpl* = ref object of RootObj
    # AnyPointer can be created in two ways: either by unpacking Capnp object or by wrapping a Nim one.
    case kind: AnyPointerKind
    of AnyPointerKind.unpacker:
      unpacker: Unpacker
      segment: int
      offset: int
    of AnyPointerKind.obj:
      typeIndex: int
      pack: proc(p: Packer, offset: int)
      unwrap: proc(dest: pointer)

forwardRefImpl(AnyPointer, AnyPointerImpl)

proc castAs*[T](selfR: AnyPointer, ty: typedesc[T]): T =
  let self: AnyPointerImpl = selfR
  case self.kind:
    of AnyPointerKind.unpacker:
      self.unpacker.currentSegment = self.segment
      return unpackPointer(self.unpacker, self.offset, T)
    of AnyPointerKind.obj:
      if getTypeIndex(T) != self.typeIndex:
        raise newException(Exception, "trying to cast $1 to $2 ($3)" % [$self.typeIndex, $getTypeIndex(T), name(T)])
      self.unwrap(addr result)

proc toAnyPointer*[T](t: T): AnyPointer =
  let self = new(AnyPointerImpl)
  self.kind = AnyPointerKind.obj
  self.typeIndex = getTypeIndex(T)
  self.unwrap = proc(p: pointer) = (cast[ptr T](p))[] = t
  self.pack = proc(p: Packer, offset: int) = packPointer(p, offset, t)
  return self

proc unpackPointer*(self: Unpacker, offset: int, typ: typedesc[AnyPointer]): AnyPointer =
  return AnyPointerImpl(kind: AnyPointerKind.unpacker,
                        unpacker: self,
                        segment: self.currentSegment,
                        offset: offset)

proc capnpPackStructImpl*(p: Packer, bufferM: var string, value: AnyPointer, dataOffset: int, minDataSize=0): tuple[dataSize: int, pointerCount: int] =
  doAssert(false)
