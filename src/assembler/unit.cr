require "./assembler"
require "./loc"

# Represent a collection of line of code.
# Statements can references each others in the same unit.
# An unit assume it will be loaded at 0.
class RiSC16::Assembler::Unit
  @base_address : Word
  @program = [] of Loc
  @symbols = {} of String => {loc: Loc?, address: Word}
  @externs = {} of String => Word

  getter program
  getter symbols

  def initialize(globals = {} of String => Word, @base_address = 0u16)
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
      loc.label.try do |label|
        @symbols[label] = {loc: loc, address: address}
        @externs[label] = address if loc.extern
      end
    end
  end
  
  # Iterate statelement with their expected loading address (relative to unit)
  def each_with_address
    @program.reduce(@base_address) do |address, loc|
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
