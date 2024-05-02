# A scope represent a bunch of symbols that exists
class Stacklang::Scope
  class Local
    property offset : Int32
    property typing : Type
  end

  class Global
    property symbol : String
    property typing : Type
  end

  alias Symbol = Local | Global

  property parent : Scope?
  property name : String

  def initialize(@parent, @name)
    @map = {} of String => Symbol
  end

  def [](symbol_name : String) : Symbol?
    @map[symbol_name]? || @parent.try &.[symbol_name]
  end

  def []=(name : String, value : Symbol)
    @map[symbol_name] = value
  end
end
