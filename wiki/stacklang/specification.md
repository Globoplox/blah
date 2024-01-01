# Stacklang specifications

Stacklang is a rudimentory C-like language. 
The top level of a stacklang file can contain:
- Requirement, to bring in prototypes of external symbols
- Global variable
- Structure type declarations
- Function declarations

## Entry point

When building a raw binaray, the entry point of the program is the `main` function. It is expected to be present by the language runtime.  

## Comments

Stacklang source can be commented by putting comment between `/*` and `*/`.
```sl
fun main:_ {
    a = 1 + 2
    /* 
      this is not code
    */
    return a
}
```

## Types

Stacklang has four primitive types / category of types:
- The word type, written `_`, which represent a single 16bit word. Signedness is up to interpretation.
  In the various place where a type constraint is required but optionnal, this is the default type.  
- Table types are used for fixed size continuous data of similar types: `[<size>]<target>` 
  - `[10]_` is a table of 10 word. The target is optional and default to `_`, so this is the same as `[10]`
  - `[0x_1_0]*_` is a table of ten pointer to word
  - `[3][2]` is a table of three table of two word
- Pointer types, written `*<target>`. Pointer are used to store addresses.  
  - The target is optionnal and default to word. This mean `*` and `*_` are both pointer to word.
  - `**` or `**_` are pointer to pointer to word
  - `*Entry` is a pointer to structure of type `Entry`. 
- Structure type, which are used defined and whose name must starts with an uppercase letter and 
  can contain letters and underscores

## Defining Functions

Functions definitions starts with the `fun` keyword, followed by the name, parameters and an optionnal return type restriction. 
When declaring a prototype for a function implemented in a scope that cannot be reached during this compiler run, the `fun` keyword can be followed by `extern`. See [Referencing other symbols](Referencing-other-symbols). In this case, the function must not have a body.
Examples:
```sl
fun add(a:_, b:_):_ {
    return a + b
}
```

Parameters types restriction defaults to `_` if ommited:
```sl
fun add(a, b):_ {
    return a + b
}
```

The function can have no return type.
```sl
fun main() {
    return
}
```

If it has no parameter, the parenthesis can be omitted:
```sl
fun main {
    return
}
```

And a function unreachable during a compiler run can be prototyped to be linked later:
`fun extern exit`

### Returning value

`TODO`

## Defining Globals

Globals definitions starts with the `var` keyword followed by the var name and an optionnal type restriction. Type restriction are incated by semicolon `:`, and if omitted the restriction default to `_`.
Globals names can contains lowercase letters and underscore.  
When declaring a prototype for a global implemented in a scope that cannot be reached during this compiler run, the `var` keyword can be followed by `extern`. See [Referencing other symbols](Referencing-other-symbols).
Examples: 
- `var global`
- `var str: *`
- `var extern some_buffer: [0x10]`

## Defining Structures

`TODO`

## Referencing symbols outside the unit

The stacklang compiler work at the unit level. It compiles a single stacklang source file
and produce a single object file. Similarly to C, thoses files must then be linked together with the stacklang runtime to produce an executbale object or raw binary file:

```mermaid
flowchart LR
    s1[a.sl] --> c1{Compiler} --> o1[a.ro] --> l
    s2[b.sl] --> c2{Compiler} --> o2[b.ro] --> l
    std[Stacklang stdlib & runtime] ---> l{Linker}
    l --> a.out
```

However, unlike C, stacklang does not requires headers file. It can extract prototypes from required sources:

```mermaid
flowchart LR
    s1[main.cr] --> c1{Compiler} --> o1[main.ro]
    s2[utils.sl] --> c2{Compiler} --> o2[utils.ro]
    s2 --> c1
```

Requirement path can be relative to the source file or absolute.

*main.sl*:
```
require "utils"

fun main {
    utils_init()
    return utils_func(1) + utils_global
}
```

*utils.sl*:
```sl
var util_global 

fun utils_init {
    utils_global = 5
}

fun utils_func(p):_ {
    return p + 10
}
```

### Referencing other symbols 

It is possible to declare external symbols through prototypes:

```
var extern util_global 
fun extern utils_init
fun extern utils_func(p):_

fun main {
    utils_init()
    return utils_func(1) + utils_global
}
```

At link time, it will be necessary to provide implementations.  

A symbol cannot be declared twice, even with the same prototype and no conflicting implementations, in the same compiler run.

## Statements and Expression

### Conditional

`TODO`

### Loops

`TODO`

### Operatos

#### Struct member access

`TODO`

#### Unary operators

`TODO`

#### Binary operators

`TODO`

#### Operators precedence and associativity

The operator precedence is based on the [crystal lang operator precedence](https://crystal-lang.org/reference/1.10/syntax_and_semantics/operators.html#operator-precedence).

All operators, ordered by decreasing precedence:

| Kind | Operators  |  Associativity |
| --- | ------------- | ------------- |
| Unary | !, ~, &, *, - | None |
| Multiplicative | *, ~ | Left |
| Additive | +, - | Left |
| Shift | <<, >> | Left |
| Binary AND | & | Left |
| Binary OR and XOR | \|, ^ | Left |
| Equality | ==, != | Left |
| Comparison | <, >, <=, >= | Left |
| Logical And | && | Left |
| Logical Or | \|\| | Left |
| Affectation | =, +=, -= | Right |

### Call

`TODO`

### Parenthesis

An expression can be wrapped in parenthesis. It allows to prevent unwanted operator precedence.
```sl
fun main:_ {
    return a + (5 & 10)
    /* is not the same as */
    return a + 5 & 10
    /* Because parenthsis prevent the higher precedence of + over & */
}
```

### Sizeof

An expression in the form `sizeof(<Type>)` take the value of the **word** (not **BYTE**) size of the type.  
Example:
```
fun main {
    /* 0x30 is ascii for 0 */
    /* A ptr size is always one word, so a table of 6 word ptr is 6 */
    __io_tty = 0x30 + sizeof([6]*_)
}
```

Will display 6.

### Cast

`TODO`
