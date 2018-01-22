import persondef, capnp

let p = new(Person)
let d = new(Date)

p.usosIds = @[1.int64, 2, 3, 4, 5, 6, 7, 8]
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
echo packed.repr

writeFile("person.bin", packed)

let p1 = newUnpackerFlat(packed).unpackPointer(0, Person)
echo p1.repr
