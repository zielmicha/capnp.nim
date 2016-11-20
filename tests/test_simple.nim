import capnp
import examples/persondef, capnp

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

let packed = packStruct(p)
let p1 = newUnpackerFlat(packed).unpackPointer(0, Person)
assert p.isAwesome == p1.isAwesome
assert p.name == p1.name
assert p.phones.len == 2
assert p.notes == p1.notes
