require "./error"
require "./unit"
require "../parser"
require "./codegen/native/generator"

# Stacklang compiler.
# This particular class does the following:
# - parse a stacklang file
# - solve requirements
# - extract and build cache of units
class Stacklang::Compiler
  # Cache of all units opened
  @units = {} of Path => Unit
  # The unit to compile
  @unit : Unit?
  getter spec

  def initialize(path : String, @spec : RiSC16::Spec, @debug = true)
    absolute = Path[path].expand home: true
    begin
      ast = Stacklang::Parser.open path, &.unit
    rescue syntax_error : Parser::Exception
      raise Exception.new syntax_error.message, cause: syntax_error
    end
    @unit = Unit.new ast, absolute, self
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
  def require(path : String, from : Unit) : Unit
    path += ".sl" unless path.includes? '.'
    absolute = Path[path].expand home: true, base: from.path.dirname
    @units[absolute]? || begin
      @units[absolute] = Unit.new Stacklang::Parser.open(absolute.to_s, &.unit), absolute, self
    rescue syntax_error : Parser::Exception
      raise Exception.new syntax_error.message, cause: syntax_error
    end
  end
end
