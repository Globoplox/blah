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
  - table access
  - All non-word sized address handling
  - Maybe: else blocks ? No condition while ?
*/

require "stdlib/multiply"


fun main:_ {
  var a:[2]
  a[0] = 1
  a[a[0]] = 0xFFBC
  return a[1]
}