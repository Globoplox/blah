#!/bin/bash
./bin/cli -l stdlib/*.blah stdlib/*.sl -o build/stdlib.lib
./bin/cli -b build -s stdlib/default_spec.ini build/stdlib.lib examples/echo_stacklang/echo.sl -o build/echo
