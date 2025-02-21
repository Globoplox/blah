require "./parser_primitive"
require "./ast"

class RiSC16::Assembler::Parser < Parser
  include RiSC16::Assembler::AST
  @path : String? = nil

  class Exception < ::Exception
  end

  rule def number
    sign = str(["-", "+"]) || ""
    case str ["0x", "0b"]
    when "0x" then base = 16
    when "0b" then base = 2
    else           base = 10
    end
    next unless digits = one_or_more ->{ char ['0'..'9', 'a'..'f', 'A'..'F'] }
    (sign + digits.join).to_i32 base: base
  end

  rule def string
    next unless char '"'
    text = consume_until "\""
    next unless char '"'
    text = text.gsub("\\t", "\t").gsub("\\n", "\n").gsub("\\r", "\r").gsub("\\0", "\0")
    next if text =~ /\\[^\\]/
    Text.new text.gsub("\\\\", "\\")
  end

  rule def register
    next unless char 'r'
    next unless digit = char '0'..'7'
    Register.new digit.to_i32
  end

  rule def reference
    next unless char ':'
    next unless symbol = one_or_more ->{ char ['0'..'9', '_'..'_', 'a'..'z', 'A'..'Z'] }
    symbol.join
  end

  rule def immediate
    symbol = reference
    offset = number
    next unless symbol || offset
    Immediate.new offset || 0, symbol
  end

  rule def comment
    next unless char '#'
    consume_until "\n"
  end

  rule def separator
    whitespace
  end

  rule def instruction
    next unless memo = one_or_more ->{ char ['a'..'z', '.'..'.'] }
    had_whitespace = whitespace
    parameters = zero_or_more ->{ or ->register, ->immediate, ->string }, separated_by: ->separator
    next unless parameters.empty? || had_whitespace
    Instruction.new memo.join, parameters
  end

  rule def statement
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

  rule def export_keyword
    next unless str "export"
    next unless whitespace
    true
  end

  rule def label_definition
    exported = export_keyword != nil
    next unless label = one_or_more ->{ char ['0'..'9', '_'..'_', 'a'..'z', 'A'..'Z'] }
    next unless char ':'
    {label.join, exported}
  end

  rule def section_specifier
    next unless str "section"
    next unless whitespace
    weak = str "weak"
    next unless whitespace if weak
    next unless name = one_or_more ->{ char ['0'..'9', '_'..'_', 'a'..'z', 'A'..'Z'] }
    whitespace
    offset = checkpoint do
      next unless char '+'
      whitespace
      number
    end
    if weak
      weak = true
    else
      weak = false
    end
    Section.new name.join, offset, weak: weak
  end

  rule def unit
    multiline_whitespace
    statements = zero_or_more ->statement, separated_by: ->multiline_whitespace
    multiline_whitespace
    next unless read_fully?
    Unit.new statements.reject(&.empty?)
  end

  def initialize(path : String)
    @path = path
    File.open path do |io|
      super(io)
    end
  end

  def initialize(io : IO)
    @path = nil
    super(io)
  end
end
