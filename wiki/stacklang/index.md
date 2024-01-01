# Stacklang

Stacklang is a work-in-progress, rudimentary C-inspired imperative language.  

```sl
require "things_doer"

fun main {
    return do_the_thing()
}
```

It is composed of:
- A compiler parsing stacklang files (.sl) and producing [object files](/wiki/object.md)
- A minimalistic standard library

While being more practical to use than assembly, it is not very efficient.  
It is not feature complete, can be buggy, has specification hole and pretty much a constant WIP.
But outside of heavy refactoring time it does works.  

## Specification 
See [Specifications](/wiki/stacklang/specification.md).

## Usage 

A minimal example:

*main.sl*:
```sl
require "utils.sl"

fun main {
  __io_tty = get_default_char()
  return
}
```

*utils.sl*:
```sl
fun get_default_char:_ {
  return 0x40
}
```

Build and run:
```
mkdir -p build
# Build and bundle the runtime 
./bin/cli -l -u stdlib/stacklang_startup.blah -o build/stdlib.lib
# Build and run using defaults specs
./bin/cli -u examples/syntax_check/*.sl build/stdlib.lib -o build/syntax_check
```

It should print a single `@` char then exit.

## Internal
See [Specifications](/wiki/stacklang/internal).
