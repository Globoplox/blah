# A minimalistic filesystem
# Definition, tool for building, lib for interaction
module Ufs
  # The point of a fs is to (often persistanty) store data: read, maybe write, files, which are a bunch of data with metadata.
  # What medata do we need: an uniq identifier, a human compatible name. They can be the same thing.
  # Other metadata: user, timestamp, format. None of them is critical.
  # A rellay minimal FS would be:
  # A header: magic, block size, block amounts, index size. (we need blocks to handle appending to files.)  
  # An index/linked list of metadata (name, size, block index) 
end

# This FS will be driven by a 'block device' kind of IO ?
## need: description, address, data, control, status register
## address and data: straightforward
## status: readable,writable, available, errored,
## control: auto increment address on/off (when a read or write happen), power on/off (i guess)
## description: would be defined by a kind of acpi

## Or maybe: instead of single register, could exposer a 'block size' memory mapped data bus. Much faster.

# Also: would there be a way to 'synchronize' clockwise, so the device and cpu can share timing info in unit of clock cycle ?
