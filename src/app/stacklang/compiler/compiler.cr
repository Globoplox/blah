require "./error"
require "./unit"
require "../parser"
require "./codegen/native"

# Stacklang compiler.
# This particular class does the following:
# - parse a stacklang file
# - solve requirements
# - extract and build cache of units
class Stacklang::Compiler
  # Cache of all units opened
  @units = {} of String => Unit
  # The unit to compile
  @unit : Unit?
  getter spec

  @fs : App::Filesystem
  @events : App::EventStream

  def initialize(path : String, @spec : RiSC16::Spec, @debug : Bool, @fs : App::Filesystem, @events : App::EventStream)
    absolute = @fs.absolute path
    ast = @fs.read path do |io|
      Stacklang::Parser.new(io, path).unit
    end

    @unit = Unit.new ast, absolute, self, @events
    @units[absolute] = @unit.not_nil!
  end

  # This is a test of the three address code generation
  def compile : RiSC16::Object
    unit = @unit.not_nil!

    object = RiSC16::Object.new unit.path.to_s
    object.sections << Stacklang::Native.generate_global_section unit.self_globals.reject &.extern

    globals = unit.self_globals.compact_map do |global|
      ({global.name, global.typeinfo}) unless global.extern
    end

    unit.self_functions.each do |func|
      next if func.ast.extern
      func.check_fix_termination
      codes = ThreeAddressCode.translate func
      object.sections << Stacklang::Native.generate_function_section func, codes
    end

    return object
  end

  # Fetch a required unit from cache or parse it.
  # Cached in a cache common with provided entrypoints units.
  def require(path : String, from : Unit, require_chain : Array(Unit)) : Unit
    dir, base, ext = @fs.base path
    raise "Requirement cannot be a directory" if base.nil?
    ext ||= ".sl"
    path = @fs.path_for dir, base, ext
    base_dir, _, _ = @fs.base from.path
    absolute = @fs.absolute path, root: base_dir
    @units[absolute]? || begin
      @fs.read absolute do |io|
        @units[absolute] = Unit.new Stacklang::Parser.new(io, absolute).unit, absolute, self, @events, require_chain
      end
    end
  end
end