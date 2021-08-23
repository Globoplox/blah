require "./right_bitshift.sl"
require "./prototypes.sl"

fun putword(word) {
  var i = 16
  while (i != 0)
    __io_tty_a = *(&hex_digits + ((word >> (i -= 4)) & 0xf))
  return
}