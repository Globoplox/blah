require "crypto/bcrypt"

class Api

  class Request::CreateFile
    include JSON::Serializable
    property path : String
  end

  route POST, "/projects/:project_id/file", def create_file(ctx)
    user_id = authenticate(ctx)
    project_id = UUID.new ctx.path_parameter "project_id"

    # if path has base dir, check that this dir exists

    file = ctx >> Request::CreateFile

    Validations.validate! do
      accumulate "path", check_file_path file.path
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

    ctx.response.status = HTTP::Status::CREATED
    ctx << Response::ID.new file_id
  end


  route POST, "/projects/:project_id/directory", def create_directory(ctx)
    user_id = authenticate(ctx)
    project_id = UUID.new ctx.path_parameter "project_id"

    # if path has base dir, check that this dir exists

    file = ctx >> Request::CreateFile

    Validations.validate! do
      accumulate "path", check_directory_path file.path
    end

    file_id = @files.insert(
      project_id: project_id,
      author_id: user_id,
      blob_id: nil,
      path: file.path
    )

    ctx.response.status = HTTP::Status::CREATED
    ctx << Response::ID.new file_id
  end

  class Request::UpdateFile
    include JSON::Serializable
    property content : String
  end

  route PUT, "/projects/:project_id/files/:id", def update_file(ctx)
    user_id = authenticate(ctx)
    project_id = UUID.new ctx.path_parameter "project_id"
    file_id = UUID.new ctx.path_parameter "file_id"
    file = ctx >> Request::UpdateFile
    
    blob_id = @files.get_blob_id(file_id)

    raise "No a file, cannot put content in a direcotry" unless blob_id

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

    ctx.response.status = HTTP::Status::NO_CONTENT
  end

  route DELETE, "/projects/:project_id/file/:file_id", def delete_file(ctx)
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
    property from : String
    property to : String
  end

  route PUT, "/projects/:project_id/files/move", def move_file(ctx)
    user_id = authenticate(ctx)
    project_id = UUID.new ctx.path_parameter "project_id"
    raise NotImplementedError.new "Feature not implemented"
  end

end
