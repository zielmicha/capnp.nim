import capnp, capnp/gensupport, collections/iface

# file: examples/person.capnp

type
  Person* = ref object
    name*: string
    email*: string
    phones*: seq[Person_PhoneNumber]
    birthdate*: Date
    notes*: seq[string]
    isAwesome*: bool
    isCloseFriend*: bool
    usosIds*: seq[int64]

  Person_PhoneNumber* = ref object
    number*: string
    `type`*: Person_PhoneNumber_Type

  Person_PhoneNumber_Type* {.pure.} = enum
    mobile = 0, home = 1, work = 2

  Date* = ref object
    year*: int16
    month*: uint8
    day*: uint8

  PersonContainer* = ref object
    person*: AnyPointer



makeStructCoders(Person, [], [
  (name, 0, PointerFlag.text, true),
  (email, 1, PointerFlag.text, true),
  (phones, 2, PointerFlag.none, true),
  (birthdate, 3, PointerFlag.none, true),
  (notes, 4, PointerFlag.text, true),
  (usosIds, 5, PointerFlag.none, true)
  ], [
  (isAwesome, 0, false, true),
  (isCloseFriend, 1, true, true)
  ])

makeStructCoders(Person_PhoneNumber, [
  (`type`, 0, Person_PhoneNumber_Type(0), true)
  ], [
  (number, 0, PointerFlag.text, true)
  ], [])

makeStructCoders(Date, [
  (year, 0, 0, true),
  (month, 2, 0, true),
  (day, 3, 0, true)
  ], [], [])

makeStructCoders(PersonContainer, [], [
  (person, 0, PointerFlag.none, true)
  ], [])


