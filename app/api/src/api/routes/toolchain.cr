require "blah-toolchain"
require "colorize"

# A fs that use the storage and database
#
# TODO: acl
# TODO: cross projects path
# TODO: parent directory on write
class JobFileSystem < Toolchain::Filesystem
  @storage : Storage
  @users : Repositories::Users
  @projects : Repositories::Projects
  @files : Repositories::Files
  @blobs : Repositories::Blobs
  @project_id : UUID
  @user_id : UUID
  @events : Toolchain::EventStream

  def initialize(@storage, @users, @projects, @files, @blobs, @project_id, @user_id, @events)
  end

  def normalize(path : String) : String
    path
  end

  def absolute(path : String, root = nil) : String
    if root
      Path[path].expand(home:true, base: root).to_s
    else
      Path[path].expand(home:true).to_s
    end
  end

  # TODO limit maximum individual file size
  # Apply quotas
  class StorageIO < IO::Memory
    def initialize(@storage : Storage, @blobs : Repositories::Blobs, @files : Repositories::Files, @path : String, @project_id : UUID, @user_id : UUID)
      super()
    end

    def close
      size = bytesize
      rewind
      content_type = "text/plain"
      
      file = @files.read_by_path(@path)
      if file
        blob_id = file.blob_id
        if blob_id
          @blobs.update(blob_id, size)
        else
          raise "exists but is a directory"
        end
      else
        blob_id = @blobs.insert(
          content_type: content_type,
          size: size
        )

        @files.insert(
          project_id: @project_id,
          author_id: @user_id,
          blob_id: blob_id,
          path: @path
        )
      end

      @storage.put(
        data: self, 
        mime: content_type, 
        name: blob_id.to_s,
        acl: Storage::ACL::Private
      )

      super()
    end
  end

  def open(path : String, mode : String) : IO

    case mode
    when "r"
      file = @files.read_by_path(path)

      if file.nil?
        @events.fatal!(title: "File '#{path}' does not exists") {}
      end

      blob_id = file.blob_id
      unless blob_id
        raise "exists but is a dir"
      end

      uri = @storage.uri blob_id.to_s, internal: true
      content = HTTP::Client.get uri do |response|
        if response.success?
          response.body_io.getb_to_end
        else
          raise "Could not open '#{path}'"
        end
      end  
      return IO::Memory.new content, writeable: false
    
    when "w"
      # Create all intermediary subdirecotry if they dont exists
      return StorageIO.new @storage, @blobs, @files, path, @project_id, @user_id

    else raise "bad mode '#{mode}'"
    end
  end

  def directory?(path : String) : Bool
    path.ens_with? "/"
  end

  def base(path : String) : {String, String?, String?}
    dir = File.dirname(path) || "."
    ext = File.extname path
    base = File.basename path, ext
    base = nil if base.empty?
    ext = nil if ext.empty?
    {dir, base, ext}
  end

  def path_for(directory : String, basename : String?, extension : String?)
    basename = "#{basename}#{extension}" if basename && extension
    Path[(directory || "."), basename].to_s
  end
end

class JobEventStream < Toolchain::EventStream
  @socket : HTTP::WebSocket

  def initialize(@socket)
  end

  protected def location(source : String?, line : Int32?, column : Int32?) : String?
    location = [] of String
    location << "in '#{source}'" if source
    location << "at #{emphasis("line #{line}")}" if line                                                                                                    
    location << "column #{column}" if column                                                                                                                
    return nil if location.empty?
    location.join " "
  end

  def emphasis(str)
    str.colorize.bold.underline
  end

  protected def event_impl(level : Level, title : String, body : String?, locations : Array({String?, Int32?, Int32?}))
    @socket.send(String.build do |io|
  
      io << case level
        in Level::Warning then level.colorize(:yellow).bold
        in Level::Error then level.colorize(:red).bold
        in Level::Fatal then level.colorize(:red).bold
        in Level::Context then level.colorize(:grey).bold
      end

      io << ": "
      io << title

      locs = locations.compact_map do |(source, line, column)|
        location(source, line, column)
      end

      if locs.empty?
        io << '\n'
      elsif locs.size == 1 && (body || @context.empty?)
        io << " "
        io << locs.first
        io << '\n'
      else
        io << '\n'
        locs.each do |location|
          io << "- "
          io << location.capitalize
          io << '\n'
        end
      end

      io.puts body if body && !body.empty?

      @context.reverse_each do |(title, source, line, column)|
        io << "While "
        io << title
        location(source, line, column).try do |l|
          io << " "
          io << l
        end
        io << '\n'
      end

      io.puts  
    end)
  end

end