#!/bin/bash
mkdir -p build
./bin/cli -l stdlib/left_bitshift.sl stdlib/multiply.blah stdlib/putword.sl stdlib/right_bitshift.sl stdlib/stacklang_startup.blah -o build/stdlib.lib
./bin/cli asm -b build -s examples/koos/spec.ini -d device=build/os -t 0x40 examples/koos/os.sl build/stdlib.lib -o build/os
./bin/cli asm -r -g -b build -s examples/koos/spec.ini -d device=build/os examples/koos/mbr.blah -o build/mbr
