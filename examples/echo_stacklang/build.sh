#!/bin/bash
mkdir -p build
./bin/cli -l stdlib/left_bitshift.sl stdlib/multiply.blah stdlib/putword.sl stdlib/right_bitshift.sl stdlib/stacklang_startup.blah -o build/stdlib.lib
./bin/cli -b build -s examples/echo_stacklang/spec.ini examples/echo_stacklang/echo.sl build/stdlib.lib -o build/echo
