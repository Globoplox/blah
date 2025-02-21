# Command Line Interface


Build the command line with the crystal shard tool:  
`shards build cli`  
Or with docker:  
`docker run -v './:/root' -w /root crystallang/crystal:1.15.0-alpine shards build cli`

The CLI binary will be found in `./bin/cli`.  

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

### Enable debugger

Flags `-g` or `--debug` can be used to enable the [Debugger](/wiki/debugger.md) when running, which displays a curse based interface.

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

If none is provided it use the [default specification](spec.md#default).

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

Assemble or compile the given files and link them into a raw binary.   
If the build-library option is enabled, build a libray instead.  

### [Running](#run)

Start a VM, load and run the given raw binary file.  
The TTY IO if any will be linked to the cli STDIN and STDOUT.

### [Default](#defaut)

If no command is given, it will run the `asm` command with the following options:
- `--also-run`
- `--unclutter`

Input files (assembly files `.blah`, stacklang file `.sl` or relocatable object `.ro`) will be compiled, assembled and linked together into a raw binary file, wich will be loaded into a virtual machine and ran.