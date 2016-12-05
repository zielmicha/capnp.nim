import examples/persondef, capnp, collections

let p = new(Person)
p.name = "HHHHHHHHHHHHH"
let p1 = PersonContainer(person: p.toAnyPointer)
let serialized0 = p.packPointer
echo newUnpackerFlat(serialized0).unpackPointer(0, Person).pprint
let serialized = p1.packPointer
echo serialized.pprint
let p2 = newUnpackerFlat(serialized).unpackPointer(0, PersonContainer)
echo p2.pprint
echo p2.person.castAs(Person).pprint
