# included from capnp.nim

type
  AnyPointerKind {.pure.} = enum
    unpacker
    obj
    cap

  AnyPointerImpl* = ref object of RootObj
    # AnyPointer can be created in two ways: either by unpacking Capnp object or by wrapping a Nim one.
    case kind: AnyPointerKind
    of AnyPointerKind.unpacker:
      unpacker: Unpacker
      segment: int
      offset: int
    of AnyPointerKind.obj:
      typeIndex: int
      when not defined(release):
        typename: string
      getPointerField: proc(index: int): AnyPointer
      pack: proc(p: Packer, offset: int)
      unwrap: proc(dest: pointer)
    of AnyPointerKind.cap:
      capServer: CapServer

forwardRefImpl(AnyPointer, AnyPointerImpl)

proc castAs*[T](selfR: AnyPointer, ty: typedesc[T]): T =
  let self: AnyPointerImpl = selfR
  case self.kind:
    of AnyPointerKind.unpacker:
      self.unpacker.currentSegment = self.segment
      return unpackPointer(self.unpacker, self.offset, T)
    of AnyPointerKind.obj:
      if getTypeIndex(T) != self.typeIndex:
        raise newException(Exception, "trying to cast $1 ($4) to $2 ($3)" % [$self.typeIndex, $getTypeIndex(T), name(T),
                                                                             when defined(release): "?" else: self.typename])

      self.unwrap(addr result)
    of AnyPointerKind.cap:
      when T is CapServer:
        return self.capServer
      elif T is SomeInterface:
        return T.createFromCap(self.capServer)
      else:
        raise newException(Exception, "trying to cast capability to $1" % [name(T)])

proc castAs*(selfR: AnyPointer, ty: typedesc[AnyPointer]): AnyPointer =
  return selfR

proc toAnyPointer*(t: AnyPointer): AnyPointer =
  return t

proc toAnyPointer*[T](t: T): AnyPointer =
  when T is CapServer:
    let self = new(AnyPointerImpl)
    self.kind = AnyPointerKind.cap
    self.capServer = t
    return self
  elif T is SomeInterface:
    return toAnyPointer(t.toCapServer)
  else:
    let self = new(AnyPointerImpl)
    self.kind = AnyPointerKind.obj
    self.typeIndex = getTypeIndex(T)
    self.unwrap = proc(p: pointer) = (cast[ptr T](p))[] = t
    self.pack = proc(p: Packer, offset: int) =
      packPointer(p, offset, t)
    when not defined(release):
      self.typename = name(T)

    self.getPointerField = proc(index: int): AnyPointer =
      mixin getPointerField
      when not (T is SomeInt or T is enum or T is string or T is seq or T is SomeInterface):
        return getPointerField(t, index)
      else:
        raise newException(Exception, "getPointerField not supported for " & name(T))
    return self

proc getPointerField*(p: AnyPointer, index: int): AnyPointer =
  if p == nil:
    raise newException(Exception, "getPointerField on nil")

  let self: AnyPointerImpl = p

  case self.kind:
  of AnyPointerKind.unpacker:
    self.unpacker.currentSegment = self.segment
    let newOffset = self.unpacker.getPointerFieldOffset(self.offset, index)
    return AnyPointerImpl(kind: AnyPointerKind.unpacker, unpacker: self.unpacker, segment: self.segment, offset: newOffset)
  of AnyPointerKind.obj:
    return (self.getPointerField)(index)
  of AnyPointerKind.cap:
    raise newException(Exception, "cap doesn't have fields")

proc setCapGetter*(p: AnyPointer, r: (proc(val: RawCapValue): CapServer)) =
  # a bit hacky, assumes one interface getter per unpacker
  AnyPointerImpl(p).unpacker.customUnpacker = true
  AnyPointerImpl(p).unpacker.getCap = r

proc unpackPointer*(self: Unpacker, offset: int, typ: typedesc[AnyPointer]): AnyPointer =
  return AnyPointerImpl(kind: AnyPointerKind.unpacker,
                        unpacker: self,
                        segment: self.currentSegment,
                        offset: offset)

proc copyPointer*(src: Unpacker, offset: int, dst: Packer, targetOffset: int)

proc packPointer*(p: Packer, offset: int, value: AnyPointer) =
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
  of AnyPointerKind.cap:
    packPointer(p, offset, self.capServer)

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

  if bodyOffset < 0 or bodyOffset > src.buffer.len:
    raise newException(CapnpFormatError, "invalid offset")

  case itemSizeTag:
  of {1,2,3,4,5}:
    var dataSize: int

    case itemSizeTag:
    of 1: dataSize = (itemNumber + 7) div 8
    of 2: dataSize = itemNumber
    of 3: dataSize = itemNumber * 2
    of 4: dataSize = itemNumber * 4
    of 5: dataSize = itemNumber * 8
    else: raise newException(CapnpFormatError, "invalid size tag")

    if dataSize > src.buffer.len - bodyOffset:
      raise newException(CapnpFormatError, "index error")

    src.decreaseLimit(dataSize)
    #echo offset, " -> ", targetOffset, " copyarray ", dst.buffer.len, " " , bodyOffset, " ", dataSize
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

    if itemSize < 0 or itemCount < 0:
      raise newException(CapnpFormatError, "invalid item size")

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

  else:
    raise newException(CapnpFormatError, "invalid list type")

  let relTargetBodyOffset = targetBodyOffset - targetOffset - 8
  pack(dst.buffer, targetOffset,
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
    raise newException(CapnpFormatError, "inter-segment pointers not supported for copying")
  elif kind == 3:
    # other pointer
    if src.customUnpacker:
      let pkind = extractBits(pointer, 3, bits=29)
      if pkind != 0:
        raise newException(CapnpFormatError, "found unknown 'other' pointer")

      let capId = extractBits(pointer, 32, bits=32)
      let newCapVal = dst.capToIndex(src.getCap(RawCapValue(kind: rawCapNumber, number: capId)))
      case newCapVal.kind:
      of rawCapNumber:
        let newCapId = newCapVal.number
        pack(dst.buffer, targetOffset, 3 or (newCapId shl 32))
      of rawCapValue:
        pack(dst.buffer, targetOffset, newCapVal.value)
    else:
      pack(dst.buffer, targetOffset, unpack(src.buffer, offset, uint64))

proc packNow*(p: AnyPointer, capToIndex: (proc(cap: CapServer): RawCapValue)): AnyPointer =
  let packer = newPacker()
  packer.capToIndex = capToIndex
  packer.packPointer(0, p)
  return unpackPointer(newUnpackerFlat(packer.buffer), 0, AnyPointer)

proc pprint*[](selfR: AnyPointer): string =
  if selfR == nil:
    return "nil"

  let self: AnyPointerImpl = selfR
  case self.kind:
    of AnyPointerKind.unpacker:
      return "AnyPointer(unpacker, " & packPointer(selfR).encodeHex & ")"
    of AnyPointerKind.obj:
      return "AnyPointer(native)"
    of AnyPointerKind.cap:
      return "AnyPointer(cap)"
