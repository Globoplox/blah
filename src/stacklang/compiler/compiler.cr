require "./error"
require "./unit"
require "../parser"
require "../../assembler/object"
require "../../spec"

class Stacklang::Compiler
  # Cache of all units opened
  @units =  {} of Path => Unit
  # The unit to compile
  @unit : Unit?
  getter spec

  def initialize(path : String, @spec : RiSC16::Spec, @debug = true)
    absolute = Path[path].expand home: true
    begin
      @units[absolute] = @unit = Unit.new Stacklang::Parser.open(path).unit, absolute, self
    rescue syntax_error : Parser::Exception
      raise Exception.new syntax_error.message, cause: syntax_error
    end
  end 
  
  def compile : RiSC16::Object
    @unit.not_nil!.compile
  end

  # Fetch a required unit from cache or parse it.
  # Cached in a cache common with provided entrypoints units.
  def require(path : String, from : Unit) : Unit
    path += ".sl" unless path.includes? '.'
    absolute = Path[path].expand home: true, base: from.path.dirname
    @units[absolute]? || begin
      @units[absolute] = Unit.new Stacklang::Parser.open(absolute.to_s).unit, absolute, self
    rescue syntax_error : Parser::Exception
      raise Exception.new syntax_error.message, cause: syntax_error
    end
  end
end
