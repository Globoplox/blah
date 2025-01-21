/*
  Tested:
  - additions (a + b + 6 + 7 + 7)
  - binary not (~0x0FF0, ~a)
  - reference of simple local or gloal identifier (&a, &glob)
  - dereference (*&b)
  - dereferenced assignement (*a = b)
  - struct field access
  - assignement, chained assignements
  TODO:
  - All binary operators: & | ^ && || == != - < > <= >=
  - Sugar assignments
  - call
  - binary to call
  - table access
  - Conditional statement
*/

var glob

fun main:_ {
  var a
  var b
  var c
  var d
  a = b = c = d = 0x5643
  return c
}
