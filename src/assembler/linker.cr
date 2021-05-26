# A static linker
module RiSC16::Linker
  extend self

  def symbols_from_spec(spec)
    predefined_symbols = {} of String => Word
    predefined_symbols["__stack"] = spec.stack_start
    spec.io.each do |io|
      absolute = spec.io_start + io.index
      # realtive value is the value (if it exists) you should add to 0 to obtain the right value.
      # This is restricted to symbols +- 2^6 (as the RiSC16 assembler use 7bit signed offset)
      # but allow to avoid aving to store the address (movi) then use it, instead the operation can use an address of 0
      # from the r0 register and use the relative symbols as an offset.
      relative = ((2 ** 7) + (absolute.to_i32 - (UInt16::MAX.to_u32 + 1)).bits(0...6)).to_u16
      predefined_symbols["__io_#{io.name}_a"] = absolute
      predefined_symbols["__io_#{io.name}_r"] = relative
    end
    predefined_symbols
  end

  # TODO:
  # get an array of units and produce a single unit
  # if one of the units has a main, another unit is added at start that will perform a jump to main ?
  # WHAT IT DO: write to the given io, in the given order, sarting at addr 0
  def links_to_bitcode(spec, units, io)

    # first pass extract exported symbols
    globals = symbols_from_spec spec
    units.reduce(0u16) do |address, unit|
      globals = globals.merge unit.exporteds address
      address + unit.word_size
    end
    
    # second write the things
    units.reduce(0u16) do |address, unit|
      unit.link address, globals
      unit.bitcode io
      address + unit.word_size
    end

    # FIXME: cache the stuff because the two pass will reuse the sames adresses and they are recomputed each time
  end

end
