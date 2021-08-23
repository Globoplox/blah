require "./unit"
require "../parser"
require "../../assembler/object"
require "../../spec"

# TODO: getting more than one path is useless.
class Stacklang::Compiler
  @units : Hash(Path, Unit)
  getter spec
  
  def initialize(paths : Array(String), @spec : RiSC16::Spec, @debug = true)
    @units = {} of Path => Unit
    @units = paths.to_h do |path|
      absolute =  Path[path].expand home: true
      File.open absolute do |file|
        parser = Stacklang::Parser.new(file, @debug)
        ast = parser.unit
        unless ast
          parser.trace_root.try &.dump
          raise "Could not parse unit '#{path}'"
        end
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
        parser = Stacklang::Parser.new(file, @debug)
        ast = parser.unit
        unless ast
          parser.trace_root.try &.dump
          raise "Could not parse unit '#{path}'"
        end
        unit = Unit.new ast, absolute, self
        @units[absolute] = unit
      end    
    end
  end
    
end
