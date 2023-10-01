# Command Line Interface

All features are accessible through a command line interface.
Build the CLI:
```sh
shards build
```

Invoke the CLI:
```sh
./bin/cli help
```

The CLI accepts various options and subcommands. 
By default if not provied a commands or options, it will attempt to compile or assembler or link all provided input files with the default linker script, then run it in a vm with the default configuration.

## Options

### Output a library:

Use flags `-l` or `--make-lib` to output a library file instead of a raw binary file. 
Library files are collection of object files.

```sh
./bin/cli -l a.blah b.sl c.ro -o test.lib
```

### Disable DCE

[Dead Code Elimination](/wiki/linker.md#dec) can be disabled through the flags `--no-dce`.
The DCE is run only when producing a raw binary file.  

### Run after assembling

Flags `-r` or `--also-run` can be used to run a file after assembly with the `asm` command.

### Unclutter intermediary file

Flags `-u` or `--unclutter` can be used to disable the serialization of intermediary output files, such as the object files generated before linking into a binary file when assembling.

### Only generate intermediary files

Flags `-i` and `--intermediary-only` can be used to disable the generation of the final binary when assembling.

### Enable debugger

Flags `-g` or `--debug` can be used to enable the [Debugger](/wiki/debugger.md) when running, which displays a curse based interface.

### Silence "No start symbol" warning

The flag `--silence-no-start` disabled a verbose warning that is displayed when assembling a raw binary file that doesn't include an exported symbol named `start`.

### Set the start address

Flags `-t <address>` or `--start=<address>` is used to specify the address at which the raw binary expect to be loaded when linked, and the address at which it is loaded into the virutal machine.

### Define Macro

Flags `-d <DEFINE>` or `--define=<DEFINE>` can be used to define values that can be used in various place, including into specification files. It can be used to easely link a given file to an IO in specification file.

Example:
```sh
./bin/cli dump-text.blah -s spec.yml -d text=text.txt
```

specification:
```ini
[hardware.segment.text]
kind=io
start=0xffff
source=$text
```

### Set the clutter directory

Flags `-b <dir>` or `--build-dir=<dir>` allows to set the subdirectory in which intermediary file are generated. It defaults to the current directory `.`.

### Set the output file name

Flag `-o <name>` or `--output=<name>` allows to set the output file name. It default to `a.out`.

### Set the specification file

Specification file that serve as linker scripts and virutal machine configuration can be specified with flags `-s <filename>` or `--spec=<filename>`.

If none is provided it use the [default specification](/wiki/spec.md#default).



## Commands

### Help

```sh
./bin/cli help
```

Will displays the CLI commands and options.

### Version

```sh
./bin/cli version
```

Will displays the global project version.

### [Assembling](#asm)

The assembler can be invoked manually through the command `asm`.

### [Running](#run)

This is the default command if none is given.
The CLI can be given an area of input files (assembly files `.blah`, stacklang file `.sl` or relocatable object `.ro`) and it will compile, assemble and link together into a raw binary file, load it into a virtual machine and run it.