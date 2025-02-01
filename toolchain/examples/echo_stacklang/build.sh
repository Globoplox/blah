#!/bin/bash
mkdir -p build
./bin/cli -l stdlib/* -o build/stdlib.lib
./bin/cli -b build -s examples/echo_stacklang/spec.ini examples/echo_stacklang/echo.sl build/stdlib.lib -o build/echo
