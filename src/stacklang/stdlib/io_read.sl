# fun io_read_bytes(io:*, at:*, max_size):_ {
# }

# fun io_read_words(io:*, at:*, max_size):_ {
#   var buffer
#   var size = 0
#   while ((buffer = *io) != 0xff00)
#     *(at + size) = buffer
#   return
# }
