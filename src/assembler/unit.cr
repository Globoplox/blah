require "./assembler"
require "./loc"

# Represent a collection of line of code.
# Statements can references each others in the same unit.
# An unit assume it will be loaded at 0.
class RiSC16::Assembler::Unit
  @program = [] of Loc
  @symbols = {} of String => {loc: Loc?, address: UInt16}
  @externs = {} of String => {loc: Loc?, address: UInt16}
  
  # class Block
  #   @section : String
  #   @offset : Int32?
  #   @program = [] of Loc
  #   def initialize(@section, @offset = nil) end
  # end

  # DEFAULT_BLOCK = Block.new "TEXT"

  # solving is removed from unit into the static linker
  # static linker use specs to get the base address and maybe the size of each sections
  # (maybe with a default TEXT section at 0
  
  getter program
  getter symbols

  def initialize(globals = {} of String => Word)
    @symbols = globals.transform_values do |address|
      {loc: nil.as(Loc?), address: address}
    end
  end
  
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
    each_with_address do |address, loc|
      loc.label.try { |label| @symbols[label] = {loc: loc, address: address} }
    end
  end
  
  # Iterate statelement with their expected loading address (relative to unit)
  def each_with_address
    @program.reduce(0u16) do |address, loc|
      begin
        yield address, loc
      rescue ex
        raise error ex, loc.file, loc.line
      end
      address + loc.stored
    end
  end
    
  # Solve references and develop pseudo-instructions.
  def solve
    each_with_address do |address, loc|
      loc.solve address, @symbols
    end
  end
  
  def write(io)
    program.map(&.statement).compact.each &.write io
  end
  
end
