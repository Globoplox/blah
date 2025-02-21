require "../../../toolchain"
require "../../../toolchain/io_event_stream"
require "../../app_filesystem"
require "shimfs"

lib LibGNU
  fun openpty(master : LibC::Int*, slave : LibC::Int*, name : Void*, termios : Void*, winsize : Void*)

  struct Winsize
    ws_row : LibC::Short
    ws_col : LibC::Short
    ws_xpixel : LibC::Short
    ws_ypixel : LibC::Short
  end
end


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

    can_read, can_write = @projects.user_can_rw project_id, user_id
    raise "Access forbidden" unless can_read

    socket_output = SocketIO.new socket

    es = Toolchain::IOEventStream.new socket_output

    user = @users.read user_id
    quota = @cache.get("users/#{user_id}/quota").try(&.to_i) || 0

    if quota + 1 > user.allowed_concurrent_job
      es.fatal!("Concurrent job quota #{quota}/#{user.allowed_concurrent_job} exceeded", nil) {}
    end

    @cache.incr "users/#{user_id}/quota"
    did_incr = true

    shimfs = Shimfs.new  1024 * 128

    fs = Toolchain::AppFilesystem.new @storage, @users, @projects, @files, @blobs, @notifications, project_id, user_id, es, shimfs

    recipe = es.with_context "Reading recipe file '#{recipe_path}'" do 
      fs.read(recipe_path) do |io|
        Recipe.from_json io
      end
    end

    toolchain = Toolchain.new false, recipe.spec_path, recipe.macros, fs, es
    on_close = [] of Proc(Void)

    spawn do
      socket.run
      on_close.each &.call
    end

    recipe.commands.each do |command|
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

          on_close.push(->() do
            socket_pipe_output.close 
            socket_pipe_input.close
            io_mapping.each do |_, value|
              in_io, out_io = value
              in_io.close
              out_io.close
            end
          end)

          remaining_step = step_limit - total_step
          total_step += toolchain.run(command.source, io_mapping, step_limit: remaining_step) do
            socket_output.puts
          end
        ensure
          socket_pipe_output.try &.close 
          socket_pipe_input.try &.close
        end

      when Recipe::Command::Debug
        begin
          # Assume frontend will have a big enough terminal         
          term_size = LibGNU::Winsize.new
          term_size.ws_col = 170
          term_size.ws_row = 40
          LibGNU.openpty(out master_fd, out slave_fd, nil, nil, pointerof(term_size))
          master = IO::FileDescriptor.new master_fd
          slave = IO::FileDescriptor.new slave_fd, blocking: true

          process = nil

          on_close.push(->() do
            process.try &.terminate unless process.try &.terminated?
            slave.close unless slave.closed?
            master.close unless master.closed?
          end)

          socket.on_message do |message|
            master.write message.to_slice
            master.flush
          end

          spawn do
            buffer = Bytes.new 1024
            until socket.closed? || master.closed?
              begin
                read = master.read buffer
                socket.send(buffer[0, read])
              rescue ex : IO::Error
                raise ex unless ex.message == "Closed stream"
              end
            end
          end
          
          args = [
            recipe.spec_path, 
            command.source, 
            command.symbol_source || "",
            project_id.to_s,
            user_id.to_s,
            shimfs.resource_name, 
            shimfs.size.to_s, 
            shimfs.address.to_s
          ]

          recipe.macros.each do |key, value|
            args << "#{key}=#{value}"
          end

          process = Process.new(
            command: Path[Process.executable_path.not_nil!, "../debugger"].normalize.to_s, 
            args: args,
            input: slave,
            output: slave,
            error: slave,
          )

          process.try &.wait
          
        ensure
          slave.close unless slave.closed? if slave
          master.close unless master.closed? if master
        end
      end
    end

  rescue ex : Toolchain::EventStream::HandledFatalException
  rescue ex
    Log.error exception: ex, &.emit "Exception during job"
  ensure
    @cache.decr "users/#{user_id}/quota" if did_incr
    socket.close
    on_close.try &.each &.call
  end

end
