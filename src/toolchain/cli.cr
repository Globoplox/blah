require "option_parser"
require "colorize"
require "./toolchain"
require "./debugger"
require "./local_filesystem"
require "./io_event_stream"

# CLI front for Toolchain.
# Run `cli --help` for usage
module Clients::Cli

  begin
    sources_files = [] of String
    spec_file = "stdlib/default_spec.ini"
    command = nil
    debug = false
    help = ""
    macros = {} of String => String
    also_run = false
    make_lib = false
    target_file = "a.out"
    target_specified = false
    no_dce = false
    create_intermediary = true
    build_dir = "./build"

    OptionParser.parse do |parser|
      parser.banner = "Usage: blah [command] [options] input_file"

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
      parser.on("-o FILENAME", "--output=FILENAME", "The output file. Created or overwriten. Default to 'a.out'.") { |filename|
        target_file = filename
        target_specified = true
      }
      parser.on("-d DEFINE", "--define=DEFINE", "Define a value for specs.") { |it| it.split('=').tap { |it| macros[it[0]] = it[1] } }
      parser.on("-u", "--unclutter", "Do not serialize the relocatable files to the build directory.") { create_intermediary = false }
      parser.on("-b DIR", "--build-dir=DIR", "Specify the directory for relocatable files.") { |directory| build_dir = directory }
      parser.on("-g", "--debug", "Run in debugger.") { debug = true }
      parser.on("-r", "--also-run", "Run the created executable.") { also_run = true }
      parser.on("-l", "--make-lib", "Make a library instead of running.") { make_lib = true }
      parser.on("--no-dce", "Disable dead code elimination when compiling an executable binary.") { no_dce = true }

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

    target_file = make_lib ? "a.lib" : "./a.out" unless target_specified

    if command.nil?
      command = :asm
      also_run = true
      create_intermediary = false
    end

    case command
    when :help
      puts help
    else

      fs = Toolchain::LocalFilesystem.new
      events = Toolchain::IOEventStream.new STDERR
      app = Toolchain.new debug, spec_file, macros, fs, events
      
      case command
      when :run
        if sources_files.empty?
          STDERR << "No program specified" 
          exit 1
        end

        if sources_files.size > 1
          STDERR << "More than one program specified" 
          exit 1
        end

        if !debug
          io_mapping = {} of String => {IO, IO}
          app.spec.segments.each do |segment|
            case segment
            when RiSC16::Spec::Segment::IO
              name = segment.name
              if name && segment.tty && segment.source.nil?
                io_mapping[name] = {STDIN, STDOUT}
              end
            end
          end
          app.run(sources_files.first, io_mapping)
        else
          fs.read sources_files.first do |input|
            io_mapping = {} of String => {IO, IO}
            app.spec.segments.each do |segment|
              case segment
              when RiSC16::Spec::Segment::IO
                name = segment.name
                if name && segment.tty && segment.source.nil?
                  io_mapping[name] = {IO::Memory.new, IO::Memory.new}
                end
              end
            end
            RiSC16::Debugger.new(input.getb_to_end, fs, app.spec, STDIN, STDOUT, io_mapping, object: nil, at: 0).run
          end
        end

      when :asm
        if sources_files.empty?
          STDERR << "No input files"
          exit 1
        end

        intermediary_dir = if create_intermediary
          build_dir
        else
          Path[Dir.tempdir, Random::DEFAULT.hex 6].to_s
        end

        Dir.mkdir_p build_dir unless Dir.exists? build_dir
        Dir.mkdir_p intermediary_dir unless Dir.exists? intermediary_dir

        objects = sources_files.map do |source|
          if source.ends_with?(".sl")
            destination = Path[intermediary_dir, Path[source.gsub(".sl", ".ro")].basename].to_s
            [app.compile(source, destination)]
            destination

          elsif source.ends_with?(".blah")
            destination = Path[intermediary_dir, Path[source.gsub(".blah", ".ro")].basename].to_s
            [app.assemble(source, destination)]
            destination

          elsif source.ends_with?(".lib") || source.ends_with?(".ro")
            source
          else
            STDERR << "Unknown type of input file: #{source}"
            exit 1
          end
        end

        if make_lib
          app.lib(objects, target_file)

        elsif also_run
          merge_destination = Path[intermediary_dir, Path[Path[target_file].basename + ".ro"]].to_s
          app.merge(objects, merge_destination, dce: !no_dce)

          destination = target_file
          app.link(merge_destination, destination)

          if also_run
            

            if !debug
              io_mapping = {} of String => {IO, IO}
              app.spec.segments.each do |segment|
                case segment
                when RiSC16::Spec::Segment::IO
                  name = segment.name
                  if name && segment.tty && segment.source.nil?
                    io_mapping[name] = {STDIN, STDOUT}
                  end
                end
              end
              
              app.run(destination, io_mapping)
            else
              binary = fs.read destination do |io|
                io.getb_to_end
              end
              
              merged_object = fs.read merge_destination do |io|
                RiSC16::Object.from_io io, name: merge_destination
              end

              io_mapping = {} of String => {IO, IO}
              app.spec.segments.each do |segment|
                case segment
                when RiSC16::Spec::Segment::IO
                  name = segment.name
                  if name && segment.tty && segment.source.nil?
                    io_mapping[name] = {IO::Memory.new, IO::Memory.new}
                  end
                end
              end

              RiSC16::Debugger.new(binary, fs, app.spec, STDIN, STDOUT, io_mapping, object: merged_object, at: 0).run
            end
          end
        end

      when nil 
        STDERR << "No command given"
        exit 1
      else 
        "Invalid command: #{command}"
      end
    end
  rescue ex: Toolchain::EventStream::HandledFatalException
    exit 1
  end
end
