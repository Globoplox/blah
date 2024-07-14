require "./error"
require "./unit"
require "../parser"
require "../../assembler/object"
require "../../spec"
require "./codegen/native"

# Stacklang compiler.
# This particular class does the following:
# - parse stacklang files
# - solve requirements
# - extract and build cache of units
# TODO: allow to use a single compiler instance for compiling several files
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
  def compile
    u = @unit.not_nil!


    globals = @unit.not_nil!.self_globals.compact_map do |global|
      ({global.name, global.typeinfo}) unless global.extern
    end

    u.self_functions.each do |f|
      next if f.ast.extern
      section = Stacklang::Native.generate f
    end

    exit 0
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
