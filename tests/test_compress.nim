import capnp

for s in ["fooobar!", "\0\0\0\0\0\0\0\0", "\0\0\0\0aaaabbbb\0opp\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0", "foobar!foobar!foobar!"]:
  let a = compressCapnp(s)
  echo repr(a)
  assert decompressCapnp(a) == s
