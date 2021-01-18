require "option_parser"
require "./assembler"
require "./vm"

module RiSC16

  module CLI
    run_vm = false
    vm_ram = VM::DEFAULT_RAM_SIZE
    target_file = "./a.out"
    source_files = [] of String
    debug_output = false
    command = nil
    help = nil
    version = nil
    
    OptionParser.parse do |parser|
      parser.banner = "Usage: blah [command] [-d] [-o ./output_file] [-m 2048] input_file"

      parser.on("asm", "Assemble source file into a binary. This is the default command.") do
        abort "Only one command can be specified. Previously set command: #{command}" unless command.nil?
        command = :assembly
      end

      parser.on("run", "Assemble source file into a binary. This is the default command.") do
        abort "Only one command can be specified. Previously set command: #{command}" unless command.nil?
        command = :run
      end
      
      parser.on("-h", "--help", "Show this help") { help = parser.to_s }
      parser.on("-v", "--version", "Display the current version") { version = "Version #{VERSION}" }
      parser.on("-o FILENAME", "--output=FILENAME", "The output file. Created or overwriten. Default to 'a.out'.") { |filename| target_file = filename }
      parser.on("-m SIZE", "--memory=SIZE", "VM Ram Size. RAM allocated to the VM.") { |ram| vm_ram = ram.to_i16 prefix: true, underscore: true }
      parser.on("-d", "--debug", "Enable debug output.") { |ram| debug_output = true }
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
    when :assembly then Assembler.assemble source_files, target_file, debug: debug_output
    when :run
      IO::Memory.new.tap do |target_buffer|
        Assembler.assemble source_files, target_buffer, debug: debug_output
        VM.new.tap do |vm|
          vm.load target_buffer.tap &.rewind
          loop do
            STDIN.read_line
            vm.dump
            vm.step
            break if vm.halted
          end
        end
      end
    end
  end
  
end
