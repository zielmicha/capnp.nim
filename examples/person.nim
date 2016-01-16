import persondef, capnp/pack, capnp/unpack

let p = new(Person)
let d = new(Date)
p.birthdate = d
d.year = 2016
d.month = 12
d.day = 5

let packed = packStruct(p)
echo packed.repr

let p1 = newUnpackerFlat(packed).unpackStruct(0, Person)
echo p1.repr
