fun left_bitshift(word, by):_ {
  while(by != 0) {
    word = word + word
    by = by - 1
  }
  return word
}