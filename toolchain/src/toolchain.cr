require "./risc16"
require "./spec"
require "./linker/object"
require "./linker/lib"
require "./linker/dce"
require "./linker/linker"
require "./assembler"
require "./stacklang/compiler"
require "./vm"
require "./debugger"

# Representation and location independant business logic
class Toolchain
  @debug : Bool
  @spec : RiSC16::Spec
  @fs : Filesystem
  @events : EventStream

  getter spec

  # Provide access to files, asbtracting actual files locations.
  abstract class Filesystem
    
    # Produce an user facing representation
    abstract def normalize(path : String) : String 

    # Return an aboslute path for the file, optionally giving a new root
    abstract def absolute(path : String, root = nil) : String

    # Open the requested file
    abstract def open(path : String, mode : String) : IO
    
    def read(path : String)
      io = open path, "r"
      result = yield io
      io.close
      return result
    end

    def write(path : String)
      io = open path, "w"
      result = yield io
      io.close
      return result
    end

    # Test if the given path is a directory
    abstract def directory?(path : String) : Bool
    
    # Split the given path in directory, base file name and file extension.
    # Note that file extension include the '.'.
    # If there are multiple extensions, only the last is returned:
    # `base "file.tar.zip"` => ".zip"
    abstract def base(path : String) : {String, String?, String?} # directory, base name, extension
    
    # Build a path given a directory, basename and extension
    abstract def path_for(directory : String, basename : String?, extension : String?)
  end

  # Provide a target for streaming warning and errors
  abstract class EventStream
    enum Level
      Warning
      Error
      Fatal
      Context
      Success
    end

    class HandledFatalException < ::Exception
    end

    @debug = false
    @errored = false
    getter errored

    def event(level : Level, title : String, body : String?, locations : Array({String?, Int32?, Int32?}))
      @errored = true if level.error? || level.fatal?
      event_impl level, title, body, locations
    end

    def event(level : Level, title : String)
      event level, title, nil, [] of {String?, Int32?, Int32?}
    end

    protected abstract def event_impl(level : Level, title : String, body : String?, locations : Array({String?, Int32?, Int32?}))

    @context = [] of {String, String?, Int32?, Int32?}
    def with_context(title : String, source : String? = nil, line : Int32? = nil, column : Int32? = nil)
      @context.push({title, source, line, column})
      begin
        yield
      rescue ex
        Log.error exception: ex, &.emit "Exception during toolchain task context"
        fatal! ex
      ensure
        @context.pop
      end
    end

    # Return the given text with emphasis if supported by implementation 
    def emphasis(str)
      str
    end

    def warn(title : String, source : String? = nil, line : Int32? = nil, column : Int32? = nil, &)
      body = String.build do |io|
        yield io
      end
      event :warning, title, body, [{source, line, column}]
    end
    
    def warn(title : String, source : String? = nil, line : Int32? = nil, column : Int32? = nil)
      event :warning, title, nil, [{source, line, column}]
    end

    def error(title : String, source : String? = nil, line : Int32? = nil, column : Int32? = nil, &)
      body = String.build do |io|
        yield io
      end
      event :error, title, body, [{source, line, column}]
    end

    def error(title : String, source : String? = nil, line : Int32? = nil, column : Int32? = nil)
      event :error, title, nil, [{source, line, column}]
    end

    def fatal!(title : String, locations : Array({String?, Int32?, Int32?}), &) : NoReturn
      body = String.build do |io|
        yield io
      end
      event :fatal, title, body, locations
      raise HandledFatalException.new
    end

    def fatal!(title : String, locations : Array({String?, Int32?, Int32?})) : NoReturn
      event :fatal, title, nil, locations
      raise HandledFatalException.new
    end

    def fatal!(title : String, source : String? = nil, line : Int32? = nil, column : Int32? = nil, &) : NoReturn
      body = String.build do |io|
        yield io
      end
      event :fatal, title, body, [{source, line, column}]
      raise HandledFatalException.new
    end

    # Log exception thrown by external source
    def fatal!(exception : Exception) : NoReturn
      case exception
      when HandledFatalException then raise exception
      else
        body = exception.message || exception.inspect
        if @debug
          body = [body, exception.backtrace.map { |s| "  from #{s}" }].flatten.join "\n"
        end
        event :fatal, exception.class.name, body, [] of {String?, Int32?, Int32?}
        raise HandledFatalException.new cause: exception
      end
    end
  end

  def initialize(@debug, spec_file : String, macros : Hash(String, String), @fs, @events)
    @spec = uninitialized RiSC16::Spec
    @events.with_context "Configuring specification '#{@events.emphasis(spec_file)}'" do 
      @spec = @fs.read spec_file do |io|
        RiSC16::Spec.open io, macros, @fs.normalize(spec_file), @events
      end
    end
  end

  # Commands methods
  # Provide pure access to compilation related functionalities. 
  # Dependency on filesystems and consoles are injected.
  # Note that command method do raise exception in case of error, additionaly to emitting error and fatal events.
  # Commands accepts inputs both as filsystem handles and occasionally as runtime object, 
  # and return runtime object additionaly to outputting to filesystem.
  # This allows instrumentation with low hassle while not compromising on performance
  # and prevent unecessary temporary / intermediate files cluttering. 

  def assemble(source : String, destination : String)
    @events.with_context "assembling #{@events.emphasis(@fs.normalize source)} into '#{@fs.normalize destination}'" do 
      object = @fs.read source do |input|
        RiSC16::Assembler.assemble(@fs.normalize(source), input, @events)
      end

      @fs.write destination do |output|
        object.to_io(output)
      end
    end
    @events.event(:success, "Successfully assembled #{@events.emphasis(@fs.normalize source)} into '#{@fs.normalize destination}'")
  end

  def compile(source : String, destination : String)
    @events.with_context "compiling #{@events.emphasis(@fs.normalize source)} into '#{@fs.normalize destination}'" do 
      object = @fs.read source do |input|
        Stacklang::Compiler.new(source, @spec, @debug, @fs, @events).compile
      end

      @fs.write destination do |output|
        object.to_io(output)
      end
    end
    @events.event(:success, "Successfully compiled #{@events.emphasis(@fs.normalize source)} into '#{@fs.normalize destination}'")
  end

  def lib(sources : Indexable(String), destination : String)
    source_names = sources.map { |source| @fs.normalize source }.join " "
    @events.with_context "making lib '#{source_names}' into '#{@fs.normalize destination}'" do 
      objects = sources.map do |source|
        _, _, source_ext = @fs.base source
        @fs.read source do |input|
          case source_ext
          when ".lib" then RiSC16::Lib.from_io(input, name: @fs.normalize source).objects
          when ".ro" then RiSC16::Object.from_io input, name: @fs.normalize source
          else raise "Unable to handle file #{@fs.normalize source}"
          end
        end
      end.flatten

      libfile = RiSC16::Lib.new(objects, name: destination)

      @fs.write destination do |output|
        libfile.to_io(output)
      end
    end
    @events.event(:success, "Successfully built lib '#{@events.emphasis(@fs.normalize destination)}'")
  end

  def merge(sources : Indexable(String), destination : String, dce : Bool = true) 

    source_names = sources.map { |source| @fs.normalize source }.join " "
    @events.with_context "merging '#{source_names}' into '#{@fs.normalize destination}'" do 
      objects = sources.map do |source|
        _, _, source_ext = @fs.base source
        @fs.read source do |input|
          case source_ext
          when ".lib" then RiSC16::Lib.from_io(input, name: @fs.normalize source).objects
          when ".ro" then RiSC16::Object.from_io input, name: @fs.normalize source
          else raise "Unable to handle file #{@fs.normalize source}"
          end   
        end
      end.flatten

      RiSC16::Dce.optimize objects if dce
      object = RiSC16::Linker.merge(@spec, objects, destination, @events)

      @fs.write destination do |output|
        object.to_io(output)
      end
    end
    @events.event(:success, "Successfully merged '#{@events.emphasis(@fs.normalize destination)}'")
  end

  def link(source : String, destination : String)
    @events.with_context "linking '#{@events.emphasis(@fs.normalize source)}'' into '#{@fs.normalize destination}'" do 
      object = @fs.read source do |input|
        RiSC16::Object.from_io input, name: @fs.normalize source
      end
      
      unless object.has_start?
        @events.warn title: "Link source merged object has no 'start' symbol", source: @fs.normalize source
      end

      raw = IO::Memory.new
      RiSC16::Linker.static_link @spec, object, raw, @events, start: 0
      
      @fs.write destination do |output|
        raw.rewind
        IO.copy src: raw, dst: output
      end
    end
    @events.event(:success, "Successfully linked '#{@events.emphasis(@fs.normalize destination)}'")
  end
 
  def run(source : String, io_mapping : Hash(String, {IO, IO})) : Void
    run(source, io_mapping) {}
  end

  def run(source : String, io_mapping : Hash(String, {IO, IO}), step_limit = nil, &) : Int32
    step_counter = 0
    vm = nil  
    @events.with_context "running '#{@fs.normalize source}'" do 
      bytes = @fs.read source do |input|
        input.getb_to_end
      end
      vm = RiSC16::VM.from_spec(spec, @fs, io_mapping)
      vm.load(bytes, at: 0)
    end
    return 0 unless vm
    @events.event(:success, "Running ... '#{@events.emphasis(@fs.normalize source)}'")
    @events.with_context "running '#{@fs.normalize source}'" do 
      step_counter = vm.run step_limit: step_limit
      yield
    end
    @events.event(:success, "Ran '#{@events.emphasis(@fs.normalize source)}'")
    vm.close
    return step_counter
  end

  def debug(source : String, symbols_object : String?, input : IO::FileDescriptor, output : IO::FileDescriptor, io_mapping : Hash(String, {IO, IO}))
    @events.with_context "debugging '#{@fs.normalize source}'" do 
      object = @fs.read symbols_object do |io|
        RiSC16::Object.from_io io, name: symbols_object
      end if symbols_object

      binary = @fs.read source do |io|
        io.getb_to_end
      end

      RiSC16::Debugger.new(binary, @fs, spec, input, output, io_mapping, object: object, at: 0).run
    end
  end
end
