#!/bin/bash
./bin/cli -l stdlib/* -o build/stdlib.lib
./bin/cli -b build -s examples/brainfuck/brainfuck.ini -d bf-source=examples/brainfuck/hello.bf examples/brainfuck/brainfuck.sl build/stdlib.lib -o build/brainfuck
