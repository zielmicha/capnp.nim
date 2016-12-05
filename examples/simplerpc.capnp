@0x8b44ecd7569600a2;

struct ContainsCap {
  cap @0 :SimpleRpc;
}

interface SimpleRpc {
  identity @0 (a :Int64) -> (b :Int64);
  dup @1 (a :Int64) -> (b :Int64, c :Int64);
}
