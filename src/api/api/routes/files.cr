require "crypto/bcrypt"

class Api

  class Request::CreateFile
    include JSON::Serializable
    property path : String
  end

  route POST, "/projects/:project_id/file", def create_file(ctx)
    user_id = authenticate(ctx)
    project_id = UUID.new ctx.path_parameter "project_id"

    can_read, can_write = @projects.user_can_rw project_id, user_id
    raise Error::Unauthorized.new "No write access for this project" unless can_write

    file = ctx >> Request::CreateFile

    Validations.validate! do
      accumulate "path", check_file_path file.path
    end

    project = @projects.read(project_id)
    count_for_project = @files.count_for_project project_id
    if count_for_project + 1 > project.allowed_file_amount
      raise Error::Quotas.new "Cannot create file #{file.path}, total allowed files count for project would exceed limit  #{count_for_project + 1}/#{project.allowed_file_amount}"
    end

    # Check that parent directory exists
    components = file.path.split('/')
    base = (components[0...(components.size - 1)] + [""]).join "/"
    unless base == "/" || @files.is_directory?(project_id, base)
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

    error = @files.insert(
      project_id: project_id,
      author_id: user_id,
      blob_id: blob_id,
      path: file.path
    )

    case error
    when Repositories::Files::DuplicatePathError
      raise Error.bad_parameter "path", "a file with the same path already exists"
    end

    @notifications.create_file(project_id, file.path)

    file = @files.read(project_id, file.path).not_nil!
    ctx.response.status = HTTP::Status::CREATED
    ctx << Response::Project::File.new(
      project_id: file.project_id,
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

    can_read, can_write = @projects.user_can_rw project_id, user_id
    raise Error::Unauthorized.new "No write access for this project" unless can_write

    file = ctx >> Request::CreateFile

    Validations.validate! do
      accumulate "path", check_directory_path file.path
    end

    project = @projects.read(project_id)
    count_for_project = @files.count_for_project project_id
    if count_for_project + 1 > project.allowed_file_amount
      raise Error::Quotas.new "Cannot create directory #{file.path}, total allowed files count for project would exceed limit  #{count_for_project + 1}/#{project.allowed_file_amount}"
    end

    # Check that parent directory exists
    components = file.path.split('/')
    base = (components[0...(components.size - 2)] + [""]).join "/"
    unless base == "/" || @files.is_directory?(project_id, base)
      raise Error.bad_parameter "path", "parent directory '#{base}' does not exist"
    end    

    error = @files.insert(
      project_id: project_id,
      author_id: user_id,
      blob_id: nil,
      path: file.path
    )

    case error
    when Repositories::Files::DuplicatePathError
      raise Error.bad_parameter "path", "a directory with the same path already exists"
    end

    @notifications.create_file(project_id, file.path)

    file = @files.read(project_id, file.path).not_nil!
    ctx.response.status = HTTP::Status::CREATED
    ctx << Response::Project::File.new(
      project_id: file.project_id,
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

  route PUT, "/projects/:project_id/files/*", def update_file(ctx)
    user_id = authenticate(ctx)
    project_id = UUID.new ctx.path_parameter "project_id"
    file_path = ctx.path_wildcard
    file = ctx >> Request::UpdateFile

    can_read, can_write = @projects.user_can_rw project_id, user_id
    raise Error::Unauthorized.new "No write access for this project" unless can_write

    existing = @files.read(project_id, file_path)
    raise Error::NotFound.new "File #{file_path} does not exists" unless existing

    blob_id = existing.blob_id
    raise Error::BadRequest.new "Not a file, cannot put content in a directory" unless blob_id

    content_type = "text/plain"
    size = file.content.size

    if size >= existing.size
      user = @users.read(user_id)
      user_sum = @files.sum_for_user(user_id)
      if user_sum + size > user.allowed_blob_size
        raise Error::Quotas.new "Cannot edit file #{file_path}, total allowed file size sum for user would exceed limit  #{user_sum + size}/#{user.allowed_blob_size}"
      end
      project = @projects.read(project_id)
      project_sum = @files.sum_for_project(project_id)
      if project_sum + size > project.allowed_blob_size
        raise Error::Quotas.new "Cannot edit file #{file_path}, total allowed file size sum for project would exceed limit  #{project_sum + size}/#{project.allowed_blob_size}"
      end
    end

    @storage.put(
      data: file.content,
      mime: content_type, 
      name: blob_id.to_s,
      acl: Storage::ACL::Private
    )

    @blobs.update(blob_id, size)

    @files.edit(project_id: project_id, path: file_path, editor_id: user_id)

    file = @files.read(project_id: project_id, path: file_path).not_nil!
    ctx.response.status = HTTP::Status::CREATED
    ctx << Response::Project::File.new(
      project_id: file.project_id,
      path: file.path,
      created_at: file.created_at,
      file_edited_at: file.file_edited_at,
      author_name: file.author_name,
      editor_name: file.editor_name,
      is_directory: file.is_directory,
      content_uri: file.blob_id.try { |blob_id| @storage.uri(blob_id.to_s) } 
    )
  end

  route DELETE, "/projects/:project_id/files/*", def delete_file(ctx)
    user_id = authenticate(ctx)
    project_id = UUID.new ctx.path_parameter "project_id"

    can_read, can_write = @projects.user_can_rw project_id, user_id
    raise Error::Unauthorized.new "No write access for this project" unless can_write

    file_path = ctx.path_wildcard
    blob_id = @files.get_blob_id(project_id: project_id, path: file_path)
    @files.delete(project_id: project_id, path: file_path)
    blob_id.try do |blob_id|
      @storage.delete(blob_id.to_s)
      @blobs.delete(blob_id)
    end

    @notifications.delete_file(project_id, file_path);

    ctx.response.status = HTTP::Status::NO_CONTENT
  end

  class Request::MoveFile
    include JSON::Serializable
    property old_path : String
    property new_path : String
  end

  route PUT, "/projects/:project_id/files/move", def move_file(ctx)
    user_id = authenticate(ctx)
    project_id = UUID.new ctx.path_parameter "project_id"
    file = ctx >> Request::MoveFile

    can_read, can_write = @projects.user_can_rw project_id, user_id
    raise Error::Unauthorized.new "No write access for this project" unless can_write

    if @files.is_directory? project_id: project_id, path: file.old_path      
      # Check path is a valid file path
      Validations.validate! do
        accumulate "path", check_directory_path file.new_path
      end
      # Check that parent directory exists
      components = file.new_path.split('/')
      base = (components[0...(components.size - 2)] + [""]).join "/"
      unless @files.is_directory?(project_id, base)
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
      unless base == "/" || @files.is_directory?(project_id, base)
        raise Error.bad_parameter "path", "parent directory '#{base}' does not exist"
      end
    end

    duplicate = @files.move(project_id, file.old_path, file.new_path, user_id)
    if duplicate
      raise Error.bad_parameter "new_path", "a file with the same path already exists"
    else
      @notifications.move_file(project_id, file.old_path, file.new_path);

      ctx.response.status = HTTP::Status::NO_CONTENT
    end
  end

end
