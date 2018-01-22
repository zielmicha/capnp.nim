#!/bin/bash
set -e
nim c capnp/capnpc
capnp compile -onim caprpc/rpc.capnp > caprpc/rpcschema.nim
capnp compile -onim caprpc/rpc-twoparty.capnp > caprpc/twopartyschema.nim
capnp compile -onim examples/calculator.capnp > examples/calculator_schema.nim
capnp compile -onim examples/simplerpc.capnp > examples/simplerpc_schema.nim
capnp compile -onim examples/nested.capnp > examples/nested_schema.nim
capnp compile -onim examples/person.capnp > examples/persondef.nim
