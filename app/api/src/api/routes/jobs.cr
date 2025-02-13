require "./toolchain"

class Api

  class Recipe
    include JSON::Serializable
    property spec_path : String
    property macros : Hash(String, String)
    property commands : Array(Command)

    abstract class Command
      include JSON::Serializable
      property command : String

      use_json_discriminator "command", {
        assemble: Assemble,
        compile: Compile,
        lib: Lib,
        merge: Merge,
        link: Link,
        run: Run,
        debug: Debug
      }

      class Assemble < Command
        property source : String
        property destination : String
      end

      class Compile < Command
        property source : String
        property destination : String
      end

      class Lib < Command
        property sources : Array(String)
        property destination : String
      end

      class Merge < Command
        property sources : Array(String)
        property destination : String
        property dce : Bool = true
      end

      class Link < Command
        property source : String
        property destination : String
      end

      class Run < Command
        property source : String
      end

      class Debug < Command
        property source : String
        property symbol_source : String?
      end
    end
  end
  
  class Request::RecipePath
    include JSON::Serializable
    property path : String
  end

  # A write only IO that wrap a socket.
  class SocketIO < ::IO
    def initialize(@socket : HTTP::WebSocket)
    end

    def read(slice : Bytes) : Int32
      0
    end

    def write(slice : Bytes) : Nil
      @socket.send slice
    end
  end

  websocket GET, "/project/:project_id/job/recipe/*", def open_job_tty(socket, ctx)
    did_incr = false
    user_id = authenticate(ctx)
    project_id = UUID.new ctx.path_parameter "project_id"
    recipe_path = ctx.path_wildcard

    es = JobEventStream.new socket

    user = @users.read user_id
    quota = @cache.get("users/#{user_id}/quota").try(&.to_i) || 0

    if quota + 1 > user.allowed_concurrent_job
      es.fatal!("Concurrent job quota #{quota}/#{user.allowed_concurrent_job} exceeded", nil) {}
    end

    @cache.incr "users/#{user_id}/quota"
    did_incr = true

    fs = JobFileSystem.new @storage, @users, @projects, @files, @blobs, @notifications, project_id, user_id, es

    recipe = es.with_context "Reading recipe file '#{recipe_path}'" do 
      fs.read(recipe_path) do |io|
        Recipe.from_json io
      end
    end

    toolchain = Toolchain.new false, recipe.spec_path, recipe.macros, fs, es
  
    recipe.commands.each do |command|
      spawn do
        socket.run
      end

      total_step = 0
      step_limit = 1_000_000

      case command
      when Recipe::Command::Assemble then toolchain.assemble(command.source, command.destination)
      when Recipe::Command::Compile then toolchain.compile(command.source, command.destination)
      when Recipe::Command::Lib then toolchain.lib(command.sources, command.destination)
      when Recipe::Command::Merge then toolchain.merge(command.sources, command.destination)
      when Recipe::Command::Link then toolchain.link(command.source, command.destination)
      when Recipe::Command::Run
        begin
          io_mapping = {} of String => {IO, IO}
          socket_pipe_output, socket_pipe_input = IO.pipe
          socket_output = SocketIO.new socket
          
          socket.on_message do |message|
            # The terminal on the other end will automatically transform '\n' it receive from us into '\r\n'
            # but when end-user hit enter, the terminal send a '\r', not a '\n'
            message = message.gsub "\r", "\n"
            eot_index = message.chars.index(&.== '\u{4}')
            if eot_index
              socket_pipe_input.write message[start: 0, count: eot_index].to_slice
              socket_pipe_input.close
            else
              socket_pipe_input.write message.to_slice
            end
          end


          toolchain.spec.segments.each do |segment|
            case segment
            when RiSC16::Spec::Segment::IO
              name = segment.name
              if name && segment.tty && segment.source.nil?
                io_mapping[name] = {socket_pipe_output, socket_output}
              end
            end
          end

          remaining_step = step_limit - total_step
          total_step += toolchain.run(command.source, io_mapping, step_limit: remaining_step) do
            socket_output.puts
            socket_output.flush
          end
        ensure
          socket_pipe_output.try &.close 
          socket_pipe_input.try &.close
        end

      when Recipe::Command::Debug
        begin
          io_mapping = {} of String => {IO, IO}
          socket_input_pipe_output, socket_input_pipe_input = IO.pipe
          socket_output_pipe_output, socket_output_pipe_input = IO.pipe
          
          socket.on_message do |message|
            # The terminal on the other end will automatically transform '\n' it receive from us into '\r\n'
            # but when end-user hit enter, the terminal send a '\r', not a '\n'
            message = message.gsub "\r", "\n"
            eot_index = message.chars.index(&.== '\u{4}')
            if eot_index
              socket_input_pipe_input.write message[start: 0, count: eot_index].to_slice
              socket_input_pipe_input.close
            else
              socket_input_pipe_input.write message.to_slice
            end
          end

          spawn do
            buffer = Bytes.new 1024
            until socket.closed? || socket_output_pipe_output.closed?
              read = socket_output_pipe_output.read buffer
              break if read == 0
              pp "READ FROM DEBUGGER OUTPUT OUTPUT #{String.new buffer[0, read]}"
              socket.send(buffer[0, read])
            end
            pp "FINISHED READING FROM DEBUGGER"
          rescue ex : IO::Error
            raise ex unless ex.message == "Closed stream"
          end

          toolchain.spec.segments.each do |segment|
            case segment
            when RiSC16::Spec::Segment::IO
              name = segment.name
              if name && segment.tty && segment.source.nil?
                io_mapping[name] = {IO::Memory.new, IO::Memory.new}
              end
            end
          end

          toolchain.debug(command.source, command.symbol_source, socket_input_pipe_output, socket_output_pipe_input, io_mapping)
          
          # Flush remaining pipe output into the socket
          socket_output_pipe_input.flush
          socket_output_pipe_input.close

          begin  
            buffer = Bytes.new 1024
            until socket.closed? || socket_output_pipe_output.closed?
              pp "Attempt to read"
              read = socket_output_pipe_output.read buffer
              break if read == 0
              pp "FLUSH READ FROM DEBUGGER OUTPUT OUTPUT #{String.new buffer[0, read]}"
              socket.send(buffer[0, read])
            end
          rescue ex
            pp "EXCEPTION DURING FLUSH"
            pp ex
          end
          pp "DONE FLUSHING"

        ensure
          pp "CLOSING ALL PIPES"
          socket_input_pipe_input.try &.close
          socket_input_pipe_output.try &.close
          socket_output_pipe_input.try &.close
          socket_output_pipe_output.try &.close      
        end
      end
    end

  rescue ex : Toolchain::EventStream::HandledFatalException
  rescue ex
    Log.error exception: ex, &.emit "Exception during job"
  ensure
    @cache.decr "users/#{user_id}/quota" if did_incr
    socket.close
  end

end