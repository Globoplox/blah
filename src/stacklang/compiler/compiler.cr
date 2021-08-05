require "./unit"
require "../parser"
require "../../assembler/object"

# TODO: getting more than one path is useless.
class Stacklang::Compiler
  @units : Hash(Path, Unit)

  def initialize(paths : Array(String))
    @units = {} of Path => Unit
    @units = paths.to_h do |path|
      absolute =  Path[path].expand home: true
      File.open absolute do |file|
        ast = Stacklang::Parser.new(file).unit || raise "Could not parse unit '#{path}'"
        unit = Unit.new ast, absolute, self
        { absolute, unit }
      end
    end    
  end

  def compile : Array(RiSC16::Object)
    @units.values.map &.compile
  end

  # Fetch a required unit from cache or parse it.
  # Cached in a cache common with provided entrypoints units.
  def require(path : String, from : Unit) : Unit
    absolute = Path[path].expand home: true, base: from.path.dirname
    @units[absolute]? || begin
       File.open absolute do |file|
       ast = Stacklang::Parser.new(file).unit || raise "Could not parse unit '#{path}'"
       unit = Unit.new ast, absolute, self
       @units[absolute] = unit
     end    
   end
  end
    
end
