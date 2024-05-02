# Translate AST to three address code.
# This does handle type checks.
struct Stacklang::ThreeAddressCode::Translator
  @tacs = [] of {Code, Type?}
  @unit : Unit
  @statements : Array(AST::Statement)
  @context : Hash(String, Type)
  @anonymous = 0
  @function : Function? # debug

  def anonymous
    Anonymous.new(@anonymous += 1)
  end

  def initialize(@statements, @unit, @function, @context)
  end
end

require "./statements"

struct Stacklang::ThreeAddressCode::Translator
  def translate : Array({Code, Type?})
    @statements.each do |statement|
      translate_statement statement
    end
    @tacs
  end
end
