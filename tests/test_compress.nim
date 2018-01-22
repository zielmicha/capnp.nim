import capnp, collections

proc check(s: string) =
  assert s.len mod 8 == 0, s
  let a = compressCapnp(s)
  assert decompressCapnp(a) == s

for s in ["fooobar!", "\0\0\0\0\0\0\0\0", "\0\0\0\0aaaabbbb\0opp\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0", "foobar!foobar!foobar!aaa"]:
  check(s)

let data = readFile("/bin/bash")

check(data)

var i = 0
let chunk = 2048*2
while i + chunk <= data.len:
  check(data[i..<i + chunk])
  i += chunk
