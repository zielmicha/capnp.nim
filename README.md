# capnp.nim
Cap'n Proto bindings for Nim

capnp.nim is a Nim implementation of Cap'n Proto serialization scheme and RPC protocol.

The serialization layer is production ready. The RPC layers is also fairly well tested, enough to be useful, but not the whole protocol is implemented.

The main user of this library is [MetaContainer](https://github.com/zielmicha/metac).

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
import persondef, capnp
# unpack the raw serialized data
let p: Person = newUnpackerFlat(packed).unpackStruct(0, Person)
# and pack again
let packed2 = packStruct(p)
```

### Debugging options

Define the following symbols during compilation (e.g `-d:caprpcTraceMessages`):

  * `caprpcTraceMessages` - print all messages sent by RPC system
  * `caprpcTraceLifetime` - print info about `release` messages, useful while debugging cross-machine leaks
  * `caprpcPrintExceptions` - print exceptions raised inside called methods (server)
