require "crypto/bcrypt"

class Api

  class Request::CreateFile
    include JSON::Serializable
    property path : String
  end

  route POST, "/projects/:project_id/file", def create_file(ctx)
    user_id = authenticate(ctx)
    project_id = UUID.new ctx.path_parameter "project_id"

    file = ctx >> Request::CreateFile

    Validations.validate! do
      accumulate "path", check_file_path file.path
    end

    # Check that parent directory exists
    components = file.path.split('/')
    base = (components[0...(components.size - 1)] + [""]).join "/"
    unless @files.directory_exists?(base)
      raise Error.bad_parameter "path", "parent directory '#{base}' does not exist"
    end

    content_type = "text/plain"
    size = 0

    blob_id = @blobs.insert(
      content_type: content_type,
      size: size
    )
    
    @storage.put(
      data: Bytes.empty, 
      mime: content_type, 
      name: blob_id.to_s,
      acl: Storage::ACL::Private
    )

    file_id = @files.insert(
      project_id: project_id,
      author_id: user_id,
      blob_id: blob_id,
      path: file.path
    )

    case file_id
    when Repositories::Files::DuplicatePathError
      raise Error.bad_parameter "path", "a file with the same path already exists"
    end

    file = @files.read file_id
    ctx.response.status = HTTP::Status::CREATED
    ctx << Response::Project::File.new(
      id: file.id,
      path: file.path,
      created_at: file.created_at,
      file_edited_at: file.file_edited_at,
      author_name: file.author_name,
      editor_name: file.editor_name,
      is_directory: file.is_directory,
      content_uri: file.blob_id.try { |blob_id| @storage.uri(blob_id.to_s) } 
    )
  end

  route POST, "/projects/:project_id/directory", def create_directory(ctx)
    user_id = authenticate(ctx)
    project_id = UUID.new ctx.path_parameter "project_id"

    file = ctx >> Request::CreateFile

    Validations.validate! do
      accumulate "path", check_directory_path file.path
    end

    # Check that parent directory exists
    components = file.path.split('/')
    base = (components[0...(components.size - 2)] + [""]).join "/"
    unless @files.directory_exists?(base)
      raise Error.bad_parameter "path", "parent directory '#{base}' does not exist"
    end    

    file_id = @files.insert(
      project_id: project_id,
      author_id: user_id,
      blob_id: nil,
      path: file.path
    )

    case file_id
    when Repositories::Files::DuplicatePathError
      raise Error.bad_parameter "path", "a directory with the same path already exists"
    end

    file = @files.read file_id
    ctx.response.status = HTTP::Status::CREATED
    ctx << Response::Project::File.new(
      id: file.id,
      path: file.path,
      created_at: file.created_at,
      file_edited_at: file.file_edited_at,
      author_name: file.author_name,
      editor_name: file.editor_name,
      is_directory: file.is_directory,
      content_uri: file.blob_id.try { |blob_id| @storage.uri(blob_id.to_s) } 
    )
  end

  class Request::UpdateFile
    include JSON::Serializable
    property content : String
  end

  route PUT, "/projects/:project_id/files/:file_id", def update_file(ctx)
    user_id = authenticate(ctx)
    project_id = UUID.new ctx.path_parameter "project_id"
    file_id = UUID.new ctx.path_parameter "file_id"
    file = ctx >> Request::UpdateFile
    
    blob_id = @files.get_blob_id(file_id)

    raise "No a file, cannot put content in a directory" unless blob_id

    content_type = "text/plain"
    size = file.content.size

    @storage.put(
      data: file.content, 
      mime: content_type, 
      name: blob_id.to_s,
      acl: Storage::ACL::Private
    )

    @blobs.update(blob_id, size)

    @files.edit(file_id: file_id, editor_id: user_id)

    file = @files.read file_id
    ctx.response.status = HTTP::Status::CREATED
    ctx << Response::Project::File.new(
      id: file.id,
      path: file.path,
      created_at: file.created_at,
      file_edited_at: file.file_edited_at,
      author_name: file.author_name,
      editor_name: file.editor_name,
      is_directory: file.is_directory,
      content_uri: file.blob_id.try { |blob_id| @storage.uri(blob_id.to_s) } 
    )
  end

  route DELETE, "/projects/:project_id/files/:file_id", def delete_file(ctx)
    user_id = authenticate(ctx)
    project_id = UUID.new ctx.path_parameter "project_id"
    file_id = UUID.new ctx.path_parameter "file_id"

    blob_id = @files.get_blob_id(file_id)
    @files.delete(file_id: file_id)
    blob_id.try do |blob_id|
      @storage.delete(blob_id.to_s)
      @blobs.delete(blob_id)
    end

    ctx.response.status = HTTP::Status::NO_CONTENT
  end

  class Request::MoveFile
    include JSON::Serializable
    property new_path : String
  end

  route PUT, "/projects/:project_id/files/:file_id/move", def move_file(ctx)
    user_id = authenticate(ctx)
    project_id = UUID.new ctx.path_parameter "project_id"
    file_id = UUID.new ctx.path_parameter "file_id"
    file = ctx >> Request::MoveFile

    if @files.is_directory? file_id      
      # Check path is a valid file path
      Validations.validate! do
        accumulate "path", check_directory_path file.new_path
      end
      # Check that parent directory exists
      components = file.new_path.split('/')
      base = (components[0...(components.size - 2)] + [""]).join "/"
      unless @files.directory_exists?(base)
        raise Error.bad_parameter "path", "parent directory '#{base}' does not exist"
      end

    else
      # Check path is a valid directory path
      Validations.validate! do
        accumulate "path", check_file_path file.new_path
      end
      # Check that parent directory exists
      components = file.new_path.split('/')
      base = (components[0...(components.size - 1)] + [""]).join "/"
      unless @files.directory_exists?(base)
        raise Error.bad_parameter "path", "parent directory '#{base}' does not exist"
      end
    end

    duplicate = @files.move(file_id, file.new_path, user_id)
    if duplicate
      raise Error.bad_parameter "new_path", "a file with the same path already exists"
    else
      ctx.response.status = HTTP::Status::NO_CONTENT
    end
  end

end
