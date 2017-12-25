import capnp, capnp/gensupport

type
  Pair* = ref object
    first*: AnyPointer
    second*: AnyPointer

makeStructCoders(Pair, [],
  [
    (first, 0, PointerFlag.none, true),
    (second, 1, PointerFlag.none, true)
  ], [])

proc packPointerHook*[A, B](p: Packer, offset: int, value: (A, B)) =
  packPointer(p, offset, Pair(first: value[0].toAnyPointer, second: value[1].toAnyPointer))

proc unpackPointerHook*[A, B](self: Unpacker, offset: int, typ: typedesc[(A, B)]): (A, B) =
  let p = unpackPointer(self, offset, Pair)
  (p.first.castAs(A), p.second.castAs(B))

proc getPointerField*[A, B](value: (A, B), index: int): AnyPointer =
  if index == 0:
    return value[0].toAnyPointer
  elif index == 1:
    return value[1].toAnyPointer
  else:
    raise newException(ValueError, "bad index")
