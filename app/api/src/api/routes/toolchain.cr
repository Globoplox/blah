require "../../toolchain"
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
  @notifications : Repositories::Notifications
  @project_id : UUID
  @user_id : UUID
  @events : Toolchain::EventStream

  def initialize(@storage, @users, @projects, @files, @blobs, @notifications, @project_id, @user_id, @events)
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
    components = path.split(":")
    if components.size == 1
      user_id = @user_name
      project_id = @project_name
      path = components[0]
    elsif components.size == 2
      user_id = @user_name
      project_id = components[0]
      path = components[1]
    elsif components.size == 3
      user_id = components[0]
      project_id = components[1]
      path = components[2]
    else
      @events.fatal!("Invalid path #{path}") {}
    end

    if path.starts_with? "/"
      [user_id, project_id, path].compact.join ':'
    else
      [user_id, project_id, Path[root || "/"].join(Path[path].relative_to(root || "/")).normalize.to_s].compact.join ':'
    end
  end
  
  # TODO limit maximum individual file size
  # Apply quotas
  class StorageIO < IO::Memory
    @storage : Storage 
    @users : Repositories::Users
    @projects : Repositories::Projects
    @blobs : Repositories::Blobs 
    @files : Repositories::Files 
    @notifications : Repositories::Notifications 
    @path : String
    @project_id : UUID 
    @user_id : UUID

    def initialize(@storage, @users, @projects, @blobs, @files, @notifications, @path, @project_id, @user_id)
      super()
    end

    def close
      size = bytesize
      rewind
      content_type = "text/plain"
      
      file = @files.read(@project_id, @path)
      if file
        blob_id = file.blob_id
        if blob_id

          if size >= file.size
            user = @users.read(@user_id)
            user_sum = @files.sum_for_user(@user_id)
            if user_sum + size > user.allowed_blob_size
              raise "Cannot edit file #{file.path}, total allowed file size sum for user would exceed limit  #{user_sum + size}/#{user.allowed_blob_size}"
            end
            project = @projects.read(@project_id)
            project_sum = @files.sum_for_project(@project_id)
            if project_sum + size > project.allowed_blob_size
              raise "Cannot edit file #{file.path}, total allowed file size sum for project would exceed limit  #{project_sum + size}/#{project.allowed_blob_size}"
            end
          end

          @blobs.update(blob_id, size)
        
        else
          raise "exists but is a directory"
        end
      else


        project = @projects.read(@project_id)
        count_for_project = @files.count_for_project @project_id

        # CREATE ALL SUBDIRECTORIES
        components = @path.split('/')
        (1..(components.size - 1)).each do |level|
          base = (components[0...level] + [""]).join "/"
          if base == "/" || @files.is_directory?(@project_id, base)
          else
            if count_for_project + 1 > project.allowed_file_amount
              raise "Cannot create parent directory #{base}, total allowed files count for project would exceed limit  #{count_for_project + 1}/#{project.allowed_file_amount}"
            end
            count_for_project += 1
            @files.insert(
              project_id: @project_id,
              author_id: @user_id,
              blob_id: nil,
              path: base
            )

            @notifications.create_file(@project_id, base)
          end
        end

        if count_for_project + 1 > project.allowed_file_amount
          raise "Cannot create file #{@path}, total allowed files count for project would exceed limit  #{count_for_project + 1}/#{project.allowed_file_amount}"
        end
        count_for_project += 1

        user = @users.read(@user_id)
        user_sum = @files.sum_for_user(@user_id)
        if user_sum + size > user.allowed_blob_size
          raise "Cannot edit file #{@path}, total allowed file size sum for user would exceed limit  #{user_sum + size}/#{user.allowed_blob_size}"
        end
        project = @projects.read(@project_id)
        project_sum = @files.sum_for_project(@project_id)
        if project_sum + size > project.allowed_blob_size
          raise "Cannot edit file #{@path}, total allowed file size sum for project would exceed limit  #{project_sum + size}/#{project.allowed_blob_size}"
        end

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

        @notifications.create_file(@project_id, @path)

      end

      @storage.put(
        data: self, 
        mime: content_type, 
        name: blob_id.to_s,
        acl: Storage::ACL::Private
      )

    ensure
      super()
    end
  end

  def open(path : String, mode : String) : IO
    user_name, project_name, path = absolute(path, "/").split(":")
    if user_name == @user_name
      user_id = @user_id
    else
      user = @users.get_by_name(user_name)
      if user.nil?
        @events.with_context "Opening '#{path}'" do
          @events.fatal!("User '#{user_name}' not found") {}
        end
      end
      user_id = user.id
    end

    if user_id == @user_id && project_name == @project_name
      project_id = @project_id
    else
      project = @projects.get_by_user_and_name(user_id, project_name)
      if project.nil?
        @events.with_context "Opening '#{path}'" do
          @events.fatal!("Project '#{project_name}' not found") {}
        end
      end
      project_id = project.id
    end

    case mode
    when "r"
      file = @files.read(project_id, path)

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
      
      # return an handle that will actually write/create the file on close. 
      return StorageIO.new @storage, @users, @projects, @blobs, @files, @notifications, path, @project_id, @user_id
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

    @socket.send str
  end

end