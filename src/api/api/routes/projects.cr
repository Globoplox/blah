require "crypto/bcrypt"

class Api

  class Request::CreateProject
    include JSON::Serializable
    property name : String
    property public : Bool
    property description : String?
  end

  route POST, "/projects/create", def insert_project(ctx)
    user_id = authenticate(ctx)

    project = ctx >> Request::CreateProject

    description = project.description
    description = nil if description.try &.empty?

    Validations.validate! do
      accumulate "name", check_project_name project.name
      if description
        accumulate "description", check_project_description description 
      end
    end

    count_for_user = @projects.count_for_user user_id
    user = @users.read(user_id)
    if count_for_user + 1 > user.allowed_project
      raise Error::Quotas.new "Cannot create project #{project.name}, project count would exceed limit #{user.allowed_project}"
    end

    project_id = @projects.insert(
      name: project.name,
      owner_id: user_id,
      public: project.public,
      description: description,
      allowed_blob_size: 1_000_000,
      allowed_file_amount: 50
    )

    case project_id
    when Repositories::Projects::DuplicateNameError
      raise Error.bad_parameter "name", "a project with the same name already exists"
    end

    ctx.response.status = HTTP::Status::CREATED
    ctx << Response::ID.new project_id
  end

  class Response::Project
    include JSON::Serializable
    property id : UUID
    property name : String
    property public : Bool
    property description : String?
    property created_at : Time
    property owner_name : String
    property files : Array(File)?
    property owned : Bool?
    property can_write : Bool?
    property acl : Array(Acl)?
    property avatar_uri : String?

    class Acl
      include JSON::Serializable
      property user_id : UUID
      property name : String
      property avatar_uri : String?
      property can_read : Bool
      property can_write : Bool

      def initialize(@user_id, @name, @avatar_uri, @can_write, @can_read)
      end
    end

    class File
      include JSON::Serializable
      property project_id : UUID
      property path : String
      property is_directory : Bool
      property content_uri : String?
      property created_at : Time
      property file_edited_at : Time
      property author_name : String
      property editor_name : String

      def initialize(@project_id, @path, @is_directory, @content_uri, @created_at, @file_edited_at, @author_name, @editor_name)
      end
    end

    def initialize(@id, @name, @public, @description, @created_at, @owner_name, @files = nil, @owned = nil, @can_write = nil, @acl = nil, @avatar_uri = nil)
    end
  end

  def repository_file_to_response_file(file : Repositories::Files::File) : Response::Project::File
    Response::Project::File.new(
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

  route GET, "/projects/:id", def read_project(ctx)
    user_id = authenticate(ctx)
    project_id = UUID.new ctx.path_parameter "id"

    can_read, can_write = @projects.user_can_rw project_id, user_id
    raise Error::Unauthorized.new "No read access for this project" unless can_read

    project = @projects.read(project_id)
    files = @files.list(project_id)

    if project.owner_id == user_id
      acl = @projects.acl(project_id)
    else
      acl = nil
    end

    ctx << Response::Project.new(
      id: project.id,
      name: project.name,
      public: project.public,
      description: project.description,
      created_at: project.created_at,
      owner_name: project.owner_name,
      owned: project.owner_id == user_id,
      can_write: can_write,
      avatar_uri: project.avatar_blob_id.try { |blob_id| @storage.uri(blob_id.to_s) },
      files: files.map do |file|
        repository_file_to_response_file file
      end, 
      acl: acl.try &.map do |acl|
        Response::Project::Acl.new(
          user_id: acl.user_id,
          name: acl.user_name,
          avatar_uri: acl.avatar_blob_id.try { |blob_id| @storage.uri(blob_id.to_s) },
          can_write: acl.can_write,
          can_read: acl.can_read
        )
      end
    )
  end

  route GET, "/projects/:id/acl", def read_project_acl(ctx)
    user_id = authenticate(ctx)
    project_id = UUID.new ctx.path_parameter "id"

    project = @projects.read(project_id)
    raise Error::Unauthorized.new "No administration access for this project" unless project.owner_id == user_id


    query = ctx.request.query_params["query"]?
    query = nil if query && query.empty?

    acl = @projects.acl(project_id, query)

    ctx << acl.map do |acl|
      Response::Project::Acl.new(
        user_id: acl.user_id,
        name: acl.user_name,
        avatar_uri: acl.avatar_blob_id.try { |blob_id| @storage.uri(blob_id.to_s) },
        can_write: acl.can_write,
        can_read: acl.can_read
      )
    end
  end

  class Request::PutProjectACL
    include JSON::Serializable
    property user_id : UUID
    property can_read : Bool
    property can_write : Bool
  end

  route PUT, "/projects/:id/acl", def set_project_acl(ctx)
    user_id = authenticate(ctx)
    project_id = UUID.new ctx.path_parameter "id"

    acl_info = ctx >> Request::PutProjectACL

    project = @projects.read(project_id)
    raise Error::Unauthorized.new "No administration access for this project" unless project.owner_id == user_id

    @projects.set_acl(
      project_id: project_id, 
      user_id: acl_info.user_id, 
      can_read: acl_info.can_read, 
      can_write: acl_info.can_write
    )
  end

  route GET, "/projects/public", def search_public_project(ctx)
    user_id = authenticate(ctx)

    query = ctx.request.query_params["query"]?
    query = nil if query && query.empty?

    projects = @projects.search_public(query)

    ctx << projects.map do |project| 
      Response::Project.new(
        id: project.id,
        name: project.name,
        public: project.public,
        description: project.description,
        created_at: project.created_at,
        owner_name: project.owner_name,
        avatar_uri: project.avatar_blob_id.try { |blob_id| @storage.uri(blob_id.to_s) }
      )
    end
  end

  route GET, "/projects/owned", def search_owned_project(ctx)
    user_id = authenticate(ctx)

    query = ctx.request.query_params["query"]?
    query = nil if query && query.empty?

    projects = @projects.search_owned(user_id, query)

    ctx << projects.map do |project| 
      Response::Project.new(
        id: project.id,
        name: project.name,
        public: project.public,
        description: project.description,
        created_at: project.created_at,
        owner_name: project.owner_name,
        avatar_uri: project.avatar_blob_id.try { |blob_id| @storage.uri(blob_id.to_s) }
      )
    end
  end

  websocket GET, "/projects/:id/notifications", def open_project_notification(socket, ctx)
    user_id = authenticate(ctx)
    project_id = UUID.new ctx.path_parameter "id"
    
    can_read, can_write = @projects.user_can_rw project_id, user_id
    raise Error::Unauthorized.new "No read access for this project" unless can_read

    subscription_creation = @notifications.on_file_created project_id, ->(path : String) do
      @files.read(project_id, path).try do |file|
        socket.send({event: "created", file: repository_file_to_response_file(file)}.to_json)
      end
    end

    subscription_deleted = @notifications.on_file_moved project_id, ->(old_path : String, new_path : String) do
      @files.read(project_id, new_path).try do |file|
        socket.send({event: "moved", old_path: old_path, file: repository_file_to_response_file(file)}.to_json)
      end
    end

    subscription_moved = @notifications.on_file_deleted project_id, ->(path : String) do
      socket.send({event: "deleted", path: path}.to_json)
    end

    socket.on_close do
      subscription_creation.cancel
      subscription_deleted.cancel
      subscription_moved.cancel
    end
  end

  class RightStatus
    include JSON::Serializable

  end

end
