require "./assembler"
require "./instruction"
require "./pseudo"
require "./data"

# Represent a line of code in a program.
# A line can hold various combinaisons of elements:
# comment, label, a data statement, an instruction or a pseudo-instruction.
class RiSC16::Assembler::Loc
  property source : String
  property file : String? = nil
  property line : Int32? = nil
  property label : String? = nil
  property comment : String? = nil
  property statement : Statement? = nil
  property export : Bool? = nil
  
  def initialize(@source, @file = nil, @line = nil)
  end
  
  def parse
    lm = /^((?<export>export\s+)?(?<label>[A-Za-z0-9_]+):)?\s*((?<operation>[A-Za-z._]+)(\s+(?<parameters>[^#]*))?)?\s*(?<comment>#.*)?$/i.match @source
    raise "Syntax Error" if lm.nil?
    @label = lm["label"]?
    @export = lm["export"]? != nil    
    @comment = lm["comment"]?
    operation = lm["operation"]?
    if operation
      parameters = lm["parameters"]? || ""
      if ISA.names.map(&.downcase).includes? operation
        @statement = Instruction.parse ISA.parse(operation), parameters
      elsif Pseudo::OPERATIONS.includes? operation
        @statement = Pseudo.new operation, parameters
      elsif operation.starts_with? '.'
        @statement = Data.new operation, parameters
      else
        raise "Unknown operation '#{operation}'"
      end
    end
  end
  
  def stored
    @statement.try &.stored || 0u16
  end
  
  def solve(base_address, indexes)
    @statement.try &.solve base_address, indexes
  end
  
end
