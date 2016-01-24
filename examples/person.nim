import persondef, capnp/pack, capnp/unpack

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
echo packed.repr

writeFile("person.bin", packed)

let p1 = newUnpackerFlat(packed).unpackStruct(0, Person)
echo p1.repr
