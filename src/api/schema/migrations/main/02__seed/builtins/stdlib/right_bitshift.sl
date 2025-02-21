require "./left_bitshift.sl"

fun right_bitshift(word, by):_ {
  var in_bit = 1 << by
  var out_word = 0
  var out_bit = 1
  while (in_bit != 0) {
    if (word & in_bit)
      out_word += out_bit
    in_bit += in_bit
    out_bit += out_bit
  }
  return out_word
}