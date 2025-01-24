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
  - table access
  - All non-word sized address handling
*/

fun main:_ {
  var b = 0
  if (!0 || (1 && (0 || !1)))
    b = 0x1111
  return b
}
