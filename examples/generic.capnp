@0xa3628c00dff87c6e;

struct Person {
  name @0 :Text;
}

struct Map(Key, Value) {
  entries @0 :List(Entry);
  struct Entry {
    key @0 :Key;
    value @1 :Value;
  }
}

struct People {
  byName @0 :Map(Text, Person);
  # Maps names to Person instances.
}
