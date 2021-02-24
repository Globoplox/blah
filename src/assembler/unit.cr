require "./assembler"
require "./loc"

# Represent a collection of line of code.
# Statements can references each others in the same unit.
# An unit assume it will be loaded at 0.
class RiSC16::Assembler::Unit
  @program = [] of Loc
  @indexes = {} of String => {loc: Loc, address: UInt16}
  getter program
  getter indexes
  
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
  
  # Build an index for solving references.
  def index
    @indexes.clear
    each_with_address do |address, loc|
      loc.label.try { |label| @indexes[label] = {loc: loc, address: address} }
    end
  end
  
  # Solve references and develop pseudo-instructions.
  def solve
    each_with_address do |address, loc|
      loc.solve address, @indexes
    end
  end
  
  def write(io)
    program.map(&.statement).compact.each &.write io
  end
  
end
