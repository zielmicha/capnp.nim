# included from capnp.nim
type
  AnyPointer* = distinct RootRef

  NotImplementedError* = object of Exception

  CapServer* = distinct Interface

  RawCapValueKind* = enum
    rawCapNumber
    rawCapValue

  RawCapValue* = object
    case kind*: RawCapValueKind
    of rawCapNumber:
      number*: int
    of rawCapValue:
      value*: AnyPointer

type SomeInt = int8|int16|int32|int64|uint8|uint16|uint32|uint64

proc capnpSizeofT*[T: SomeInt|float32|float64](t: typedesc[T]): int =
  sizeof(T)

proc capnpSizeofT*[T: enum](t: typedesc[T]): int =
  sizeof(uint16)

template capnpSizeof*(e): typed =
  capnpSizeofT(type(e))

proc isNil*(a: CapServer): bool =
  return a.Interface.vtable == nil

proc decompressCapnp*(a: string): string =
  result = ""
  var i = 0
  while i < a.len:
    let tag = unpack(a, i, uint8).int
    if tag == 0x00:
      let zeroWords = unpack(a, i + 1, uint8).int + 1
      result.add(repeat("\0", zeroWords * 8))
      i += 2
    else:
      i += 1
      for j in 0..<8:
        if (tag and (1 shl j)) != 0:
          doAssert i < len(a)
          result.add(a[i])
          i += 1
        else:
          result.add('\0')

      if tag == 0xFF:
        let verbatimWords = unpack(a, i, uint8).int
        result.add(a[i + 1..<(i + 1 + verbatimWords * 8)])
        i += verbatimWords * 8 + 1

proc compressCapnp*(a: string): string =
  # TODO
  assert a.len mod 8 == 0

  result = ""
  var i = 0
  let wordCount = (a.len div 8)

  while i < wordCount:
    let word = unpack(a, i*8, uint64)
    var tag = 0
    var tagPos = result.len
    result.add('\0')
    for b in 0..<8:
      let isZero = (word and uint64(0xff shl (b*8))) == 0
      if not isZero:
        result.add(a[i*8 + b])
        tag = tag or (1 shl b)

    result[tagPos] = pack(uint8(tag))[0]
    if tag == 0xFF:
      i += 1
      var verbatimWords = 0
      while verbatimWords < 254 and i + verbatimWords < wordCount:
        var j = i + verbatimWords
        var zeroCount = 0
        for k in 0..<7:
          if a[j*8 + k] == '\0': zeroCount += 1

        if zeroCount > 1:
          break
        else:
          verbatimWords += 1

      result.add(pack(uint8(verbatimWords)))
      result.add(a[i*8..<(i+verbatimWords)*8])
      i += verbatimWords

    elif tag == 0x00:
      var cnt = 0
      while i+1 < wordCount and unpack(a, (i+1)*8, uint64) == 0 and cnt < 255:
        i += 1
        cnt += 1
      result.add(pack(uint8(cnt)))
      i += 1
    else:
      i += 1

  #result = "\xFF" & a[0..<8] & pack(uint8(a.len div 8 - 1)) & a[8..^1]
