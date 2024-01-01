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
    @units[absolute] = @unit = Unit.new Stacklang::Parser.open(path).unit, absolute, self
  end

  def compile : RiSC16::Object
    @unit.not_nil!.compile
  end

  # Fetch a required unit from cache or parse it.
  # Cached in a cache common with provided entrypoints units.
  def require(path : String, from : Unit) : Unit
    absolute = Path[path].expand home: true, base: from.path.dirname
    @units[absolute]? || begin
      @units[absolute] = Unit.new Stacklang::Parser.open(absolute.to_s).unit, absolute, self
    end
  end
end
