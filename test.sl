/*
  Tested:
  - binary operators: + & | ^ -
  - assignment and chained assignement
  - unary operator: ~ & * -
  - dereferenced assignement: n* = x
  - struct field access
  - call with return value and parameters
  - if statement
  - conditional operators: == != ! && || < <= > >=
  - while statement
  - conditonal statement values (a = 1 || 0)
  - sugar assignments
  TODO:
  - mutating unsupported operators to call
  - table access
  - All non-word sized address handling
  - Maybe: else blocks ?
*/

fun main:_ {
  var a = 0x8765
  return a
}