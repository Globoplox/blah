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

var glob

fun foo(ptr:*, a, b, c, d, e, f, g, h, i, j) {
  *ptr = a + b + c + d + e + f + g + h + i + j
}

fun main:_ {
  var a
  foo(&a, 1, 1, 1, 1, 5, 1, 1, 1, 1, 1)
  return a
}
