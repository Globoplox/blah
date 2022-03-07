fun multiply(a, b):_ {
 var result = 0
 var shift = 1
 while (shift) {
   if (b & shift)
     result += a
   a += a
   shift += shift
 }
 return result
}