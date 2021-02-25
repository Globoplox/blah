require "option_parser"
require "./spec"
require "./assembler"
require "./vm"
require "./debugger"

module RiSC16

  module CLI
    DEFAULT_TARGET = "./a.out"
    target_file = nil
    source_files = [] of String
    spec_file = nil
    command = nil
    help = nil
    version = nil
    
    OptionParser.parse do |parser|
      parser.banner = "Usage: blah [command] [-d] [-o ./output_file] [-m 2048] input_file"

      parser.on("asm", "Assemble source file into a binary.") do
        abort "Only one command can be specified. Previously set command: #{command}" unless command.nil?
        command = :assembly
      end

      # parser.on("run", "Assemble if necesary and run the specified file.") do
      #   abort "Only one command can be specified. Previously set command: #{command}" unless command.nil?
      #   command = :run
      # end

      parser.on("debug", "Assemble source file into a binary and run it.") do
        abort "Only one command can be specified. Previously set command: #{command}" unless command.nil?
        command = :debug
      end
      
      parser.on("-h", "--help", "Show this help") { help = parser.to_s }
      parser.on("-v", "--version", "Display the current version") { version = "Version #{VERSION}" }
      parser.on("-s FILENAME", "--spec=FILENAME", "The spec description file to use") { |filename| spec_file = filename }
      parser.on("-o FILENAME", "--output=FILENAME", "The output file. Created or overwriten. Default to 'a.out'.") { |filename| target_file = filename }
      parser.unknown_args do |filenames, parameters|
        source_files = filenames
      end
      parser.invalid_option do |flag|
        STDERR.puts "#{flag} is not a valid option."
        STDERR.puts parser
        exit 1
      end
    end

    puts version if version
    puts help if help
    abort "No command given." unless command || help || version

    case command
    when :assembly
      spec = spec_file.try do |file| Spec.open file end || Spec.default
      Assembler.assemble source_files, (target_file || DEFAULT_TARGET).as(String), spec
    when :debug
      spec = spec_file.try do |file| Spec.open file end || Spec.default
      buffer = IO::Memory.new
      unit = target_file.try do |target_file|
        File.open target_file, "w" do |file|
          Assembler.assemble source_files, IO::MultiWriter.new(file, buffer), spec
        end
      end || Assembler.assemble source_files, buffer, spec
      Debugger.new(unit, buffer.rewind, spec).run
    end
  end
  
end
