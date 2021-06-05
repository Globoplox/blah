require "./unit"
require "../parser"

class Stacklang::Compiler
  @units : Hash(Path, Unit)

  def initialize(paths : Array(String))
    @units = paths.to_h do |path|
      absolute =  Path[path].expend home: true
      File.open absolute do |file|
        ast = Stacklang::Parser.new(file).unit || raise "Could not compile unit '#{path}'"
        unit = Unit.new ast, absolute
        { absolute, unit }
      end
    end

    
  end

  # Fetch a required unit from cache or parse it.
  # Cached in a cache common with provided entrypoints units.
  def require(path : String, from : Unit) : Unit
    absolute = Path[requirement.target].expand home: true, base: from_unit.path.dirname
    @units[absolute]? || begin
       File.open absolute do |file|
       ast = Stacklang::Parser.new(file).unit || raise "Could not compile unit '#{path}'"
       unit = Unit.new ast, absolute
       @units[absolute] = unit
     end    
   end
                      
    
end
