# Representation and location independant business logic
# TODO: warning
# TODO: errors
# TODO: vm
# TODO: debugger

require "./risc16"
require "./spec"
require "./linker/object"
require "./linker/lib"
require "./linker/dce"
require "./linker/linker"
require "./assembler"
require "./stacklang/compiler"
require "./vm"

class App
  @debug : Bool
  @spec : RiSC16::Spec
  @fs : Filesystem

  getter spec

  def initialize(@debug, spec_file : String?, macros : Hash(String, String), @fs)
    @spec = spec_file.try do |file|
      @fs.read file, ->(io : IO) do
        RiSC16::Spec.open io, macros
      end
    end || RiSC16::Spec.default
  end

  # Provide access to files, asbtracting actual files locations
  abstract class Filesystem
    abstract def normalize(path : String) : String 
    abstract def open(path : String, mode : String) : IO
    
    def read(path : String)
      io = open(path, "r")
      v = yield io
      io.close
      v
    end

    def write(path : String)
      io = open(path, "w")
      v = yield io
      io.close
      v
    end

    abstract def directory?(path : String) : Bool
    abstract def base(path : String) : {String, String?, String?} # directory, base name, extension
    abstract def path_for(directory : String, basename : String?, extension : String?)
  end

  def assemble(source : String, destination : String?) : RiSC16::Object
    _, source_base, source_ext = @fs.base source

    object = @fs.read source do |input|
      RiSC16::Assembler.assemble(@fs.normalize(source), input)
    end

    if destination
      dest_dir, dest_base, dest_ext = @fs.base destination
      dest_ext = ".ro" unless dest_ext
      dest_base = source_base unless dest_base
      destination = @fs.path_for dest_dir, dest_base, dest_ext
      @fs.write destination do |output|
        object.to_io(output)
      end
    end
    
    return object
  end

  def open(source : String) : Array(RiSC16::Object)
    _, source_base, source_ext = @fs.base source
    @fs.read source do |input|
      case source_ext
      when ".lib" then RiSC16::Lib.from_io(input).objects
      when ".ro" then [RiSC16::Object.from_io input, name: source]
      else raise "Unable to handle file #{@fs.normalize source}"
      end   
    end
  end

  def compile(source : String, destination : String?) : RiSC16::Object
    _, source_base, source_ext = @fs.base source

    object = @fs.read source do |input|
      Stacklang::Compiler.new(source, @spec, @debug).compile
    end

    if destination
      dest_dir, dest_base, dest_ext = @fs.base destination
      dest_ext = ".ro" unless dest_ext
      dest_base = source_base unless dest_base
      destination = @fs.path_for dest_dir, dest_base, dest_ext
      @fs.write destination do |output|
        object.to_io(output)
      end
    end
    
    return object
  end

  def lib(sources : Indexable(String | RiSC16::Object | RiSC16::Lib), destination : String?) : RiSC16::Lib
    objects = sources.map do |source|
      case source
        in RiSC16::Object then source 
        in RiSC16::Lib then source.objects 
        in String
        @fs.read source do |input|
          case source_ext
          when ".lib" then RiSC16::Lib.from_io(input).objects
          when ".ro" then RiSC16::Object.from_io input, name: source
          else raise "Unable to handle file #{@fs.noramlize source}"
          end   
        end
      end
    end.flatten

    libfile = RiSC16::Lib.new(objects)

    if destination
      @fs.write destination do |output|
        libfile.to_io(output)
      end
    end
    
    return libfile
  end

  def merge(sources : Indexable(String | RiSC16::Object | RiSC16::Lib), destination : String?, dce : Bool = true) : RiSC16::Object
    objects = sources.map do |source|
      case source
        in RiSC16::Object then source 
        in RiSC16::Lib then source.objects 
        in String
        _, _, source_ext = @fs.base source
        @fs.read source do |input|
          case source_ext
          when ".lib" then RiSC16::Lib.from_io(input).objects
          when ".ro" then RiSC16::Object.from_io input, name: source
          else raise "Unable to handle file #{@fs.noramlize source}"
          end   
        end
      end
    end.flatten

    RiSC16::Dce.optimize objects if dce
    object = RiSC16::Linker.merge(@spec, objects)

    if destination
      @fs.write destination do |output|
        object.to_io(output)
      end
    end

    return object
  end

  def link(source : String | RiSC16::Object, destination : String?) : Bytes
    object = case source
    in RiSC16::Object then source 
    in String
      _, _, source_ext = @fs.base source
      @fs.read source do |input|
        case source_ext
        when ".ro" then RiSC16::Object.from_io input, name: source
        else raise "Unable to handle file #{@fs.noramlize source}"
        end
      end
    end
    
    # Log.warn &.emit "Linking into a binary without 'start' symbol" unless silence_no_start || merged_object.has_start?


    raw = IO::Memory.new
    RiSC16::Linker.static_link @spec, object, raw, start: 0
    
    if destination
      @fs.write destination do |output|
        raw.rewind
        IO.copy src: raw, dst: output
      end
    end

    return raw.to_slice
  end
 
  def run(source : String | Bytes, io_mapping : Hash(String, {IO, IO})) : Void
    bytes = case source
    in Bytes then source
    in String
      @fs.read source do |input|
        input.getb_to_end
      end
    end

    RiSC16::VM.from_spec(spec, @fs, io_mapping).tap(&.load(bytes, at: 0)).tap(&.run).close
  end
end