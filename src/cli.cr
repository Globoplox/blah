require "option_parser"
require "./assembler"
require "./vm"
require "./debugger"

module RiSC16

  module CLI
    run_vm = false
    vm_ram = VM::DEFAULT_RAM_SIZE
    DEFAULT_TARGET = "./a.out"
    target_file = nil
    source_files = [] of String
    command = nil
    help = nil
    version = nil
    
    OptionParser.parse do |parser|
      parser.banner = "Usage: blah [command] [-d] [-o ./output_file] [-m 2048] input_file"

      parser.on("asm", "Assemble source file into a binary. This is the default command.") do
        abort "Only one command can be specified. Previously set command: #{command}" unless command.nil?
        command = :assembly
      end

      parser.on("run", "Assemble source file into a binary and run it.") do
        abort "Only one command can be specified. Previously set command: #{command}" unless command.nil?
        command = :run
      end

      parser.on("debug", "Assemble source file into a binary and run it.") do
        abort "Only one command can be specified. Previously set command: #{command}" unless command.nil?
        command = :debug
      end
      
      parser.on("-h", "--help", "Show this help") { help = parser.to_s }
      parser.on("-v", "--version", "Display the current version") { version = "Version #{VERSION}" }
      parser.on("-o FILENAME", "--output=FILENAME", "The output file. Created or overwriten. Default to 'a.out'.") { |filename| target_file = filename }
      parser.on("-m SIZE", "--memory=SIZE", "VM Ram Size. RAM allocated to the VM.") { |ram| vm_ram = ram.to_i16 prefix: true, underscore: true }
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
    when :assembly then Assembler.assemble source_files, (target_file || DEFAULT_TARGET).as(String)
    when :debug
      begin
        buffer = IO::Memory.new
        unit = target_file.try do |target_file|
          File.open target_file, "w" do |file|
            Assembler.assemble source_files, IO::MultiWriter.new file, buffer
          end
        end || Assembler.assemble source_files, buffer
        Debugger.new unit, buffer.rewind
      end.run
    when :run
      IO::Memory.new.tap do |target_buffer|
        unit = Assembler.assemble source_files, target_buffer
        VM.new.tap do |vm|
          vm.load target_buffer.tap &.rewind
          vm.dump_registers
          loop do
            vm.dump_instruction
            STDIN.read_line
            vm.step
            vm.dump_registers
            break if vm.halted
          end
        end
      end
    end
  end
  
end
