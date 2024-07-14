var a
var b

struct S { j k }

fun other(i : S):_ {
  var a = i.k
}
  
fun main(a, c) {
  a = b + c  
}

fun foo:S {
  var bar : S
  bar.j = other(bar)
  return bar
}