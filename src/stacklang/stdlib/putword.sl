require "./right_bitshift.sl"
require "./prototypes.sl"

fun putword(word) {
  var i = 16
  while (i != 0) {
    i = i - 4
    *tty = *(&hex_digits + ((right_bitshift(word, i)) & 0xf))
  }
  return
}