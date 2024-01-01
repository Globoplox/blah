#!/bin/bash
mkdir -p build
./bin/cli -l stdlib/stacklang_startup.blah -o build/stdlib.lib
./bin/cli -u examples/syntax_check/*.sl examples/syntax_check/*.blah  build/stdlib.lib -o build/syntax_check
