require "option_parser"
require "./spec"
require "./assembler/parser"
require "./assembler/assembler"
require "./assembler/linker"
require "./vm"
require "./stacklang/compiler"

module RiSC16

  module CLI
    target_file = "./a.out"
    sources_files = [] of String
    spec_file = nil
    command = nil
    intermediary_only = false
    create_intermediary = true
    intermediary_dir = nil
    debug = false
    help = ""
    macros = {} of String => String
    also_run = false
    
    OptionParser.parse do |parser|
      parser.banner = "Usage: blah [command] [-d] [-o ./output_file] [-m 2048] input_file"

      parser.on("asm", "Assemble sources files") do
        abort "Only one command can be specified. Previously set command: #{command}" unless command.nil?
        command = :asm
      end

      parser.on("run", "Run the specified file.") do
        abort "Only one command can be specified. Previously set command: #{command}" unless command.nil?
        command = :run
      end

      parser.on("help", "Show this help.") do
        abort "Only one command can be specified. Previously set command: #{command}" unless command.nil?
        command = :help
      end

      parser.on("version", "Display the current version.") do
        abort "Only one command can be specified. Previously set command: #{command}" unless command.nil?
        command = :version
      end
      
      parser.on("-h", "--help", "Show this help") do
        abort "Only one command can be specified. Previously set command: #{command}" unless command.nil?
        command = :help
      end

      parser.on("-v", "--version", "Display the current version") do
        abort "Only one command can be specified. Previously set command: #{command}" unless command.nil?
        command = :version
      end
      
      parser.on("-s FILENAME", "--spec=FILENAME", "The spec description file to use.") { |filename| spec_file = filename }
      parser.on("-o FILENAME", "--output=FILENAME", "The output file. Created or overwriten. Default to 'a.out'.") { |filename| target_file = filename }
      parser.on("-d DEFINE", "--define=DEFINE", "Define a value for specs.") { |it| it.split('=').tap { |it| macros[it[0]] = it[1] }  }
      parser.on("-u", "--unclutter", "Do not serialize the relocatable files.") { create_intermediary = false }
      parser.on("-b DIR", "--build-dir=DIR", "Specify the directory for relocatable files.") { |directory| intermediary_dir = directory }
      parser.on("-g", "--debug", "Run with improved logging.") { debug = true }
      parser.on("-i", "--intermediary-only", "Do not build exectuable.") { intermediary_only = true }
      parser.on("-r", "--also-run", "Run the created executable.") { also_run = true }

      parser.unknown_args do |filenames, parameters|
        sources_files = filenames
      end
      
      parser.invalid_option do |flag|
        STDERR.puts "#{flag} is not a valid option."
        STDERR.puts parser
        exit 1
      end

      help = parser.to_s
    end

    if command.nil?
      command = :asm
      also_run = true
      create_intermediary = false
    end

    case command
    when :help
      puts help
    when :version
      puts VERSION

    when :run
      spec = spec_file.try do |file| Spec.open file, macros end || Spec.default
      raise "No program specified" if sources_files.empty?
      raise "More than one program specified" if sources_files.size > 1
      File.open sources_files.first, "r" do |file|
        VM.from_spec(spec).tap(&.load file)
      end.run

    when :asm
      spec = spec_file.try do |file| Spec.open file, macros end || Spec.default
      intermediary_dir.try do |intermediary_dir|
        Dir.mkdir_p intermediary_dir unless Dir.exists? intermediary_dir
      end
      objects = sources_files.map do |source|
        if source.ends_with?(".sl")
          object = Stacklang::Compiler.new([source]).compile.first
          name = source.gsub(".blah", ".ro")
          if create_intermediary
            File.open Path[(intermediary_dir || Dir.current).not_nil!, Path[name].basename], "w" do |output|
              object.to_io output
            end
          end
          object
        elsif source.ends_with?(".blah")
          unit = File.open source do |input|
            parser = RiSC16::Assembler::Parser.new input, debug
            parser.unit(name: source) || raise "Parse error in input file #{source}"
          end
          object = RiSC16::Assembler.assemble(unit)
          name = source.gsub(".blah", ".ro")
          if create_intermediary
            File.open Path[(intermediary_dir || Dir.current).not_nil!, Path[name].basename], "w" do |output|
              object.to_io output
            end
          end
          object
        elsif source.ends_with? ".ro"
          File.open source do |input|
            RiSC16::Object.from_io input, name: source
          end
        else raise "Unknown type of input file: #{source}" 
        end
      end

      if !intermediary_only || also_run
        binary = IO::Memory.new
        Linker.link_to_binary spec, objects, binary
        
        unless intermediary_only
          File.open target_file, "w" do |sink|
            binary.rewind
            IO.copy binary, sink
          end
        end
        
        if also_run
          binary.rewind
          VM.from_spec(spec).tap(&.load binary).run
        end
      end
    
      when nil then raise "No command given"
    else raise "Invalid command: #{command}"
    end
  end
  
end
