/*
  Tested:
  - additions
  - binary not
  - reference of simple local or gloal identifier
  - dereferencement
  - dereferenced assignement
  - struct field access
  - assignement, chained assignements
  - call with return value and parameters
  TODO:
  - All binary operators: & | ^ && || == != - < > <= >=
  - Sugar assignments
  - binary to call
  - table access
  - Conditional statement
  - All non-word sized address handling
*/

struct Test { foo bar baz }

var glob: Test

fun main:_ {
  glob.foo = 0x0FF0
  glob.baz = glob.foo
  glob.bar = 0x1111
  return glob.baz
}
