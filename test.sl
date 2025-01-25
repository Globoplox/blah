/*
  Tested:
  - binary operators: +
  - assignment and chained assignement
  - binary operator: ~, &, *
  - dereferenced assignement: n* = x
  - struct field access
  - call with return value and parameters
  - if statement
  - conditional operators: ==, !=, !, &&, ||
  TODO:
  - other conditonals statements: < <= > >=
  - while statement
  - conditonal statement values (a = 1 || 0)
  - bitwise binary operators: & | ^
  - sugar assignments
  - mutating unsupported operators to call
  - table accesss
  - All non-word sized address handling
*/

fun main:_ {
  var a = 0
  var b = 1
  while (a != 7) {
    a = a + 1
    b = b + b
  }
  return b
}