import capnp/util

type
  BitSeq* = object
    length: int
    body: string

proc newBitSeq(s: string, offset: int, itemCount: int): BitSeq =
  let bytes = int((itemCount + 7) / 8)
  if offset >= s.len or offset + bytes >= s.len:
    raise newException(CapnpFormatError, "bitseq too long")
  result.length = itemCount
  result.body = s[offset..offset + bytes]

proc len*(b: BitSeq): int =
  b.length

proc `[]`*(b: BitSeq, i: int): bool =
  (int(b.body[i shr 8]) shl (i and 0x7)) != 0

proc `[]=`*(b: var BitSeq, i: int, v: bool) =
  let bit = 1 shr (i and 0x7)
  if v:
    b.body[i shr 8] = char(int(b.body[i shr 8]) or bit)
  else:
    b.body[i shr 8] = char(int(b.body[i shr 8]) and (not bit))

proc `$`*(b: BitSeq): string =
  result = ""
  for i in 0..<b.len:
    result.add(if b[i]: "1" else: "0")
