require "blah-toolchain"
require "colorize"

# A fs that use the storage and database
#
# TODO: acl
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
    @user_name = @users.read(@user_id).name
    @project_name = @projects.read(@project_id).name
  end

  def normalize(path : String) : String
    path
  end

  # user, project, base, name, extension
  protected def components_with_remote(path) : {String?, String?, String?, String?, String?}
    comps = path.split ':'
    if comps.size == 1
      dir = File.dirname(path) || "."
      ext = File.extname path
      base = File.basename path, ext
      base = nil if base.empty?
      ext = nil if ext.empty?
      {nil, nil, dir, base, ext}
    elsif comps.size == 2
      project = comps[0]
      path = comps[1]
      dir = File.dirname(path) || "."
      ext = File.extname path
      base = File.basename path, ext
      base = nil if base.empty?
      ext = nil if ext.empty?
      {nil, project, dir, base, ext}
    elsif comps.size == 3
      user = comps[0]
      project = comps[1]
      path = comps[2]
      dir = File.dirname(path) || "."
      ext = File.extname path
      base = File.basename path, ext
      base = nil if base.empty?
      ext = nil if ext.empty?
      {user, project, dir, base, ext}
    else
      @events.fatal!("Invalid path: '#{path}'") {}
    end
  end

  def absolute(path : String, root = nil) : String
    newPath = if root
      Path[path].expand(base: root).to_s
    else
      Path[path].expand.to_s
    end
    newPath = newPath.lstrip "/" if newPath.includes? ':'
    newPath
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
      
      file = @files.read_by_path(@project_id, @path)
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
    pp "OPENIN #{path} #{mode} (#{@user_name}, #{@project_name})"


    components = path.split(":")
    user_id = @user_id
    project_id = @project_id

    if components.size == 2
      user_id = @user_id
      project = @projects.get_by_user_and_name(user_id, components[0])
      if project.nil?
        @events.with_context "Opening '#{path}'" do
          @events.fatal!("Project '#{components[0]}' not found") {}
        end
      end
      project_id = project.id
      path = components[1]
    
    elsif components.size == 3
      user = @users.get_by_name(components[0])
      if user.nil?
        @events.with_context "Opening '#{path}'" do
          @events.fatal!("User '#{components[0]}' not found") {}
        end
      end
      user_id = user.id

      project = @projects.get_by_user_and_name(user_id, components[1])
      if project.nil?
        @events.with_context "Opening '#{path}'" do
          @events.fatal!("Project '#{components[1]}' not found") {}
        end
      end
      project_id = project.id
      path = components[2]
    end

    case mode
    when "r"
      file = @files.read_by_path(project_id, path)

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
      if user_id != @user_id
        @events.with_context "Opening '#{path}'" do
          @events.fatal!("Cannot write files in other users projects") {}
        end
      end

      error = Validations::Accumulator.new.check_file_path path
      if error
        @events.with_context "Opening '#{path}'" do
          @events.fatal!("Path #{error}") {}
        end
      end

      # Create all intermediary subdirecotry if they dont exists
      return StorageIO.new @storage, @blobs, @files, path, @project_id, @user_id

    else raise "bad mode '#{mode}'"
    end
  end

  def directory?(path : String) : Bool
    path.ends_with? "/"
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
    str = String.build do |io|
  
      io << case level
        in Level::Warning then level.colorize(:yellow).bold
        in Level::Error then level.colorize(:red).bold
        in Level::Fatal then level.colorize(:red).bold
        in Level::Context then level.colorize(:grey).bold
        in Level::Success then level.colorize(:green).bold
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

      io.puts if !@context.empty?  
    end

    pp str
    @socket.send str
  end

end