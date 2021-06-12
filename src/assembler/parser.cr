require "../parsing/primitive"
require "./ast"

class RiSC16::Assembler::Parser < Parser
  include RiSC16::Assembler::AST
  @path : String? = nil

  def number
    checkpoint "literal" do
      sign = str(["-", "+"]) || ""
      base = case str ["0x", "0b"]
        when "0x" then 16
        when "0b" then 2
        else 10
      end
      pp "base: #{base}"
      (sign + mandatory(one_or_more(char ['0'..'9', 'a'..'f', 'A'..'F'])).join).to_i32 base: base
    end
  end
  
  def register
    checkpoint "register" do
      mandatory char 'r'
      Register.new (mandatory char '0'..'7').to_i32 
    end
  end

  def reference
    checkpoint "reference" do
      mandatory char ':'
      (mandatory one_or_more char ['0'..'9', '_'..'_', 'a'..'z', 'A'..'Z']).join
    end
  end

  def immediate
    checkpoint "immediate" do
      symbol = reference
      offset = number
      Immediate.new offset || 0, symbol unless symbol.nil? && offset.nil?
    end
  end
  
  def comment
    checkpoint "comment" do
      mandatory char '#'
      consume_until "\n"
    end
  end

  def separator
    checkpoint "separator" do
      mandatory whitespace
    end
  end

  def instruction
    checkpoint "instruction" do
      memo = (mandatory one_or_more char ['a'..'z', '.'..'.']).join
      had_whitespace = whitespace
      parameters = zero_or_more or(register, immediate), separated_by: separator
      pp "had_whitespace: #{had_whitespace}, parameters: #{parameters}"
      next unless parameters.empty? || had_whitespace
      Instruction.new memo, parameters
    end
  end

  def statement
    checkpoint "line" do
      whitespace
      section = section_specifier
      whitespace
      label = label_definition
      whitespace
      text = instruction
      whitespace
      comment
      Statement.new section, label, text
    end
  end

  def label_definition
    checkpoint "label" do
      label = (mandatory one_or_more char ['0'..'9', '_'..'_', 'a'..'z', 'A'..'Z']).join
      mandatory char ':'
      label
    end
  end
  
  def section_specifier
    checkpoint "section" do
      name = mandatory str "section"
      whitespace
      offset = checkpoint "section offset" do
        mandatory char '+'
        whitespace
        mandatory number
      end
      Section.new name, offset 
    end
  end
  
  def unit
    checkpoint "unit" do
      multiline_whitespace
      statements = mandatory zero_or_more statement, separated_by: multiline_whitespace
      multiline_whitespace
      mandatory read_fully?
      Unit.new statements.reject &.empty?
    end
  end

  def initialize(path : String, debug = false)
    @path = path
    File.open path do |io|
      super(io, debug)
    end
  end

  def initialize(io : IO, debug = false)
    @path = nil
    super(io, debug)
  end
  
end

pp RiSC16::Assembler::Parser.new(IO::Memory.new(ARGF.gets_to_end), true).unit
