#!/bin/bash
set -e
./util/build-schemas.sh
for name in simple; do
    echo "test $name"
    nim c -r tests/test_$name.nim
done
