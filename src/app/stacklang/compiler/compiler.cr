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
      Stacklang::Parser.new(io, path, @events).unit
    end

    @unit = Unit.new ast, absolute, self, @events, @spec
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

    function_tacs = [] of {Function, Array(ThreeAddressCode::Code)}
    
    unit.self_functions.each do |func|
      @events.with_context(
        "compiling function #{@events.emphasis(func.name)}", 
        func.ast.token.source, 
        func.ast.token.line, 
        func.ast.token.character 
      ) do
        next if func.ast.extern
        func.check_fix_termination @events
        function_tacs << {func, ThreeAddressCode.translate func, @events}
      end
    rescue ex : App::EventStream::HandledFatalException
      # Keep accumulating fatal error for all function
    end

    if @events.errored
      @events.fatal!(title: "Compilation failed at intermediary code generation") {}
    end

    function_tacs.each do |(func, codes)|
      object.sections << Stacklang::Native.generate_function_section func, codes, @events
    rescue ex : App::EventStream::HandledFatalException
      # Keep accumulating fatal error for all function
    end

    if @events.errored
      @events.fatal!(title: "Compilation failed at native code generation") {}
    end

    return object
  end

  # Fetch a required unit from cache or parse it.
  # Cached in a cache common with provided entrypoints units.
  def require(path : String, from : Unit, require_chain : Array(Unit)) : Unit
    dir, base, ext = @fs.base path
    @events.fatal!(title: "Requirement cannot be a directory", source: @fs.normalize(from.path)) {} if base.nil?
    ext ||= ".sl"
    path = @fs.path_for dir, base, ext
    base_dir, _, _ = @fs.base from.path
    absolute = @fs.absolute path, root: base_dir
    @units[absolute]? || begin
      @fs.read absolute do |io|
        @units[absolute] = Unit.new Stacklang::Parser.new(io, absolute, @events).unit, absolute, self, @events, @spec, require_chain
      end
    end
  end
end