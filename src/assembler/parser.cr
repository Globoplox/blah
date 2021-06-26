require "../parsing/primitive"
require "./ast"

class RiSC16::Assembler::Parser < Parser
  include RiSC16::Assembler::AST
  @path : String? = nil

  def number
    checkpoint do
      sign = str(["-", "+"]) || ""
      base = case str ["0x", "0b"]
        when "0x" then 16
        when "0b" then 2
        else 10
      end
      next unless digits = one_or_more ->{ char ['0'..'9', 'a'..'f', 'A'..'F'] }
      (sign + digits.join).to_i32 base: base
    end
  end

  def string
    checkpoint  do
      next unless char '"'
      text = consume_until "\""
      next unless char '"'
      text = text.gsub("\\t", "\t").gsub("\\n", "\n").gsub("\\r", "\r").gsub("\\0", "\0")
      next if text =~ /\\[^\\]/
      Text.new text.gsub("\\\\", "\\")
    end
  end
  
  def register
    checkpoint  do
      next unless char 'r'
      next unless digit = char '0'..'7'
      Register.new digit.to_i32 
    end
  end

  def reference
    checkpoint  do
      next unless char ':'
      next unless symbol = one_or_more ->{ char ['0'..'9', '_'..'_', 'a'..'z', 'A'..'Z'] }
      symbol.join
    end
  end

  def immediate
    checkpoint  do
      symbol = reference
      offset = number
      next unless symbol || offset
      Immediate.new offset || 0, symbol
    end
  end
  
  def comment
    checkpoint  do
      next unless char '#'
      consume_until "\n"
    end
  end

  def separator
    checkpoint  do
      whitespace
    end
  end

  def instruction
    checkpoint do
      next unless memo = one_or_more ->{ char ['a'..'z', '.'..'.'] }
      had_whitespace = whitespace
      parameters = zero_or_more ->{ or ->register, ->immediate, ->string }, separated_by: ->separator
      next unless parameters.empty? || had_whitespace
      Instruction.new memo.join, parameters
    end
  end

  def statement
    checkpoint  do
      whitespace
      section = section_specifier
      whitespace
      label_def = label_definition
      label, exported = label_def if label_def
      whitespace
      text = instruction
      whitespace
      comment
      Statement.new section, label, text, exported || false
    end
  end

  def export_keyword
    checkpoint  do
      next unless str "export"
      next unless whitespace
      true
    end
  end
  
  def label_definition
    checkpoint  do
      exported = export_keyword != nil
      next unless label = one_or_more ->{ char ['0'..'9', '_'..'_', 'a'..'z', 'A'..'Z'] }
      next unless char ':'
      {label.join, exported}
    end
  end
  
  def section_specifier
    checkpoint  do
      next unless str "section"
      next unless whitespace
      next unless name = one_or_more ->{ char ['0'..'9', '_'..'_', 'a'..'z', 'A'..'Z'] }
      whitespace
      offset = checkpoint do
        next unless char '+'
        whitespace
        next unless number
      end
      Section.new name.join, offset 
    end
  end
  
  def unit
    checkpoint do
      multiline_whitespace
      next unless statements = zero_or_more ->statement, separated_by: ->multiline_whitespace 
      multiline_whitespace
      next unless read_fully?
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
