fun read_io(src: *, dst: *, limit) {
    var offset = 0x0
    var read = 0x0
    while (offset < max_size && (offset == 0x0 || read != 0xff00)) {
          *(src + offset) = *(dst + offset) // Here we need to handle a special case: affectation can be done to a var OR to a dereferencement (so its always 'somewhere').
          offset = offset + 0x1
    }
    //return offset
}
