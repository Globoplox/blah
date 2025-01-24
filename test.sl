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
  - if statement
  TODO:
  - All binary operators: & | ^ && || == != - < > <= >=
  - Sugar assignments
  - binary to call
  - table access
  - Conditional statements
  - All non-word sized address handling
*/

fun main:_ {
  var a = 0
  var b = 0xFFFF

  if (a)
    b = 0x1111
  return b
}
