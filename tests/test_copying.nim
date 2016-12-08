import examples/persondef, capnp, collections

let p = new(Person)
let d = new(Date)
p.birthdate = d
p.isAwesome = true
p.isCloseFriend = false
p.name = "Hello"
p.notes = @[nil, "nope", "just a note", ""]
p.phones = @[]
let num = new(Person_PhoneNumber)
num.number = "hello"
num.`type` = Person_PhoneNumber_Type.work
p.phones.add num
let num2 = new(Person_PhoneNumber)
num2.number = "world"
num2.`type` = Person_PhoneNumber_Type.mobile
p.phones.add num2
p.email = "foo@example.com"
d.year = 2016
d.month = 12
d.day = 5

let packed = packPointer(p)
echo packed.encodeHex

discard newUnpackerFlat(packed).unpackPointer(0, Person)

let packer1 = newPacker()
copyPointer(newUnpackerFlat(packed), 0, packer1, 0)

echo packer1.buffer.encodeHex

let p1 = newUnpackerFlat(packer1.buffer).unpackPointer(0, Person)
assert p.isAwesome == p1.isAwesome
assert p.name == p1.name
assert p.phones.len == p1.phones.len
assert p.notes == p1.notes

