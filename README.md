# capnp.nim
Cap'n Proto bindings for Nim

capnp.nim is a Nim implementation of Cap'n Proto serialization scheme. It's work in progress, see [TODO.md](TODO.md). The RPC features are not implemented now, but will probably be someday.

## Installing

Use [nimble](https://github.com/nim-lang/nimble) to install `capnp.nim`:

```
nimble install capnp
```

Create symlink to `canpnc` binary result (capnp compiler expects `capnpc-nim` binary,
but Nimble is unable to produce binary name that contains `-`):

```
ln -s ~/.nimble/bin/capnpc ~/.nimble/bin/capnpc-nim
```

## Generating wrapping code

capnp.nim can generate Nim types (with some metadata) from `.capnp` file. The resulting objects use native Nim datatypes like seq or strings (this means that this implementation, unlike C++ one, doesn't have O(1) deserialization time). 

```
capnp compile -onim your-protocol-file.capnp > you-output-file.nim
```

## Using the library 

```
import persondef, capnp/pack, capnp/unpack
# unpack raw serialized data
let p: Person = newUnpackerFlat(packed).unpackStruct(0, Person)
# and pack again
let packed2 = packStruct(p)
```

