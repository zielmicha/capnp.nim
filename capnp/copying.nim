# included from capnp.nim

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
  self.pack = proc(p: Packer, offset: int) =
    packPointer(p, offset, t)
  return self

proc setCapGetter*(p: AnyPointer, r: (proc(id: int): CapServer)) =
  # a bit hacky, assumes one interface getter per unpacker
  AnyPointerImpl(p).unpacker.getCap = r


proc unpackPointer*(self: Unpacker, offset: int, typ: typedesc[AnyPointer]): AnyPointer =
  return AnyPointerImpl(kind: AnyPointerKind.unpacker,
                        unpacker: self,
                        segment: self.currentSegment,
                        offset: offset)

proc copyPointer*(src: Unpacker, offset: int, dst: Packer, targetOffset: int)

proc packPointer*[](p: Packer, offset: int, value: AnyPointer) =
  if value == nil:
    packNil(p, offset)
    return

  let self: AnyPointerImpl = value
  case self.kind:
  of AnyPointerKind.unpacker:
    self.unpacker.currentSegment = self.segment
    copyPointer(self.unpacker, self.offset, p, offset)
  of AnyPointerKind.obj:
    self.pack(p, offset)

proc copyStructInner(src: Unpacker, info: tuple[offset: int, dataLength: int, pointerCount: int], dst: Packer, targetDataOffset: int) =
  # copy contents of struct specified by `info`
  dst.buffer.insertAt(targetDataOffset, src.buffer[info.offset..<info.offset + info.dataLength])
  dst.buffer.insertAt(targetDataOffset + info.dataLength, newZeroString(info.pointerCount * 8))
  for pointerI in 0..<info.pointerCount:
    copyPointer(src, info.offset + info.dataLength + pointerI * 8,
                dst, targetDataOffset + info.dataLength + pointerI * 8)

proc copyStruct(src: Unpacker, offset: int, dst: Packer, targetOffset: int) =
  let info = src.parseStruct(offset)

  let old = src.stackLimit
  defer: src.stackLimit = old
  src.decreaseLimit(info.pointerCount * 8 + info.dataLength)

  let relTargetDataOffset = dst.buffer.len - targetOffset - 8
  copyStructInner(src, info, dst, dst.buffer.len)
  pack(dst.buffer, targetOffset,
       ((relTargetDataOffset div 8).uint64 shl 2) or
       ((info.dataLength div 8).uint64 shl 32) or
       (info.pointerCount.uint64 shl 48))

proc copyList(src: Unpacker, offset: int, dst: Packer, targetOffset: int) =
  let pointer = unpack(src.buffer, offset, uint64)
  let bodyOffset = extractBits(pointer, 2, bits=30).unpackOffsetSigned * 8 + offset + 8
  let itemSizeTag = extractBits(pointer, 32, bits=3)
  let itemNumber = extractBits(pointer, 35, bits=29)
  let targetBodyOffset = dst.buffer.len

  assert dst.buffer.len mod 8 == 0

  case itemSizeTag:
  of {1,2,3,4,5}:
    var dataSize: int

    case itemSizeTag:
    of 1: dataSize = (itemNumber + 7) div 8
    of 2: dataSize = itemNumber
    of 3: dataSize = itemNumber * 2
    of 4: dataSize = itemNumber * 4
    of 5: dataSize = itemNumber * 8
    else: doAssert(false)

    if dataSize > src.buffer.len - bodyOffset:
      raise newException(CapnpFormatError, "index error")

    src.decreaseLimit(dataSize)
    dst.buffer &= src.buffer[bodyOffset..<bodyOffset + dataSize]
    dst.buffer.padWords
  of 6:
    let dataSize = itemNumber * 8
    if dataSize > src.buffer.len - bodyOffset:
      raise newException(CapnpFormatError, "index error")

    src.decreaseLimit(dataSize)
    dst.buffer &= newZeroString(dataSize)

    for pointerI in 0..<itemNumber:
      copyPointer(src, bodyOffset + pointerI * 8,
                  dst, targetBodyOffset + pointerI * 8)
  of 7:
    if bodyOffset + 8 > src.buffer.len:
      raise newException(CapnpFormatError, "index error")

    let info = src.parseStruct(bodyOffset, parseOffset=false)
    let itemCount = info.offset
    let itemSize = (info.dataLength + 8 * info.pointerCount)

    src.decreaseLimit(itemSize)
    src.decreaseLimit(itemCount)
    src.decreaseLimit(itemSize * itemCount)

    if bodyOffset + 8 + itemSize * itemCount > src.buffer.len:
      raise newException(CapnpFormatError, "index error")

    dst.buffer &= newZeroString(8 + itemSize * itemCount)
    pack(dst.buffer, targetBodyOffset, unpack(src.buffer, bodyOffset, uint64))

    for i in 0..<itemCount:
      let itemOffset = bodyOffset + 8 + itemSize * i
      copyStructInner(src, (itemOffset, info.dataLength, info.pointerCount),
                      dst, targetBodyOffset + 8 + itemSize * i)

  else: doAssert(false)

  let relTargetBodyOffset = targetBodyOffset - targetOffset - 8
  pack(dst.buffer, offset,
       1.uint64 or
       ((relTargetBodyOffset div 8).uint64 shl 2) or
       (extractBits(pointer, 32, bits=32).uint64 shl 32))

proc copyPointer*(src: Unpacker, offset: int, dst: Packer, targetOffset: int) =
  let pointer = unpack(src.buffer, offset, uint64)
  let kind = extractBits(pointer, 0, bits=2)

  if pointer == 0:
    packNil(dst, targetOffset)
    return

  if kind == 0:
    copyStruct(src, offset, dst, targetOffset)
  elif kind == 1:
    copyList(src, offset, dst, targetOffset)
  elif kind == 2:
    doAssert(false) # inter-segment
  elif kind == 3:
    # other pointer
    discard

proc packNow*(p: AnyPointer, capToIndex: (proc(cap: CapServer): int)): AnyPointer =
  let packer = newPacker()
  packer.capToIndex = capToIndex
  packer.packPointer(0, p)
  return unpackPointer(newUnpackerFlat(packer.buffer), 0, AnyPointer)

proc pprint*(selfR: AnyPointer): string =
  if selfR == nil:
    return "nil"

  let self: AnyPointerImpl = selfR
  case self.kind:
    of AnyPointerKind.unpacker:
      return "AnyPointer(unpacker)"
    of AnyPointerKind.obj:
      return "AnyPointer(native)"
