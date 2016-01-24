import capnp/util, capnp/unpack, capnp/pack, capnp/gensupport
type
  Person_PhoneNumber* = ref object
    number*: string
    `type`*: Person_PhoneNumber_Type

  Person_PhoneNumber_Type* {.pure.} = enum
    mobile = 0, home = 1, work = 2

  Person* = ref object
    name*: string
    email*: string
    phones*: seq[Person_PhoneNumber]
    birthdate*: Date
    notes*: seq[string]
    isAwesome*: bool
    isCloseFriend*: bool

  Date* = ref object
    year*: int16
    month*: uint8
    day*: uint8



makeStructCoders(Person_PhoneNumber, [
  (`type`, 0, Person_PhoneNumber_Type(0), true)
  ], [
  (number, 0, PointerFlag.text, true)
  ], [])

makeStructCoders(Person, [], [
  (name, 0, PointerFlag.text, true),
  (email, 1, PointerFlag.text, true),
  (phones, 2, PointerFlag.none, true),
  (birthdate, 3, PointerFlag.none, true),
  (notes, 4, PointerFlag.text, true)
  ], [
  (isAwesome, 0, false, true),
  (isCloseFriend, 1, true, true)
  ])

makeStructCoders(Date, [
  (year, 0, 0, true),
  (month, 2, 0, true),
  (day, 3, 0, true)
  ], [], [])


