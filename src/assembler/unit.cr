require "./assembler"
require "./loc"

# Represent a collection of line of code.
# Statements can references each others in the same unit.
# An unit assume it will be loaded at 0.
class RiSC16::Assembler::Unit
  @program = [] of Loc
  @linked = false
  
  getter program
  
  def error(cause, name, line)
    Exception.new name, line, cause
  end
  
  # Parse the diffrent lines of codes in the given io.
  def parse(io : IO, name = nil)
    i = 1
    io.each_line do |line|
      line = line.strip
      begin
        loc = Loc.new source: line, file: name, line: i
        loc.parse
        @program << loc
      rescue ex
        raise error ex, name, i
      end
      i += 1
    end
  end

  def exporteds(base_address)
    exported_symbols = {} of String => Word
    each_with_address base_address do |address, loc|
      loc.label.try do |label|
        exported_symbols[label] = address if loc.export
      end
    end
    exported_symbols
  end

  def locals(base_address)
    local_symbols = {} of String => {loc: Loc, address: Word}
    each_with_address base_address do |address, loc|
      loc.label.try do |label|
        local_symbols[label] = {loc: loc, address: address}
      end
    end
    local_symbols
  end
  
  # Iterate statelement with their expected loading address (relative to unit)
  def each_with_address(base_address)
    @program.reduce base_address do |address, loc|
      begin
        yield address, loc
      rescue ex
        raise error ex, loc.file, loc.line
      end
      address + loc.stored
    end
  end
    
  # Solve references and develop pseudo-instructions, detect undefined symbols
  # Currently it raise on undefined, units are not yet ready for compile-time relocation
  # or caching
  def link(base_address, globals)
    local_and_global_syms = globals.transform_values do |address|
      {loc: nil.as(Loc?), address: address}
    end.merge locals base_address

    each_with_address base_address do |address, loc|
      loc.solve address, local_and_global_syms
    end
    
    @linked = true
  end

  def word_size
    @program.map(&.stored).sum
  end

  # read and write to unit file for static linking
  # Unit file would store various thing in addition to bitcode:
  # - exported symbols (currently named external, this is a mishap)
  # - external symbols (undefined references), and for each the locations of the address.
  #    we would allow undefined references (so we can compile separately) but theere must be room for a full word. It would default to zero.
  # - maybe in the future: dynamic linking table, with libs, and symbols for each lib.
  # the linker would allow to build program (need a main, no undef) and libs (no_undef) from unit file
  # by relocating, linking and generating bootstrap code.
  
  # write the raw bitcode to the given io
  def bitcode(io)
    raise "Cannot assemble an unit that has not been linked" unless @linked
    program.map(&.statement).compact.each &.write io
  end
  
end
