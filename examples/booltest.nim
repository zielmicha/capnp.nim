import booldef, capnp/pack, capnp/unpack

let p = new(BoolStore)
p.v = true
p.w = true

let packed = packStruct(p)
echo packed.repr

writeFile("bool.bin", packed)
