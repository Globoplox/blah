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

    def initialize(@id, @name, @public, @description, @created_at, @owner_name, @files = nil)
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

    project = @projects.read(project_id)
    files = @files.list(project_id)

    ctx << Response::Project.new(
      id: project.id,
      name: project.name,
      public: project.public,
      description: project.description,
      created_at: project.created_at,
      owner_name: project.owner_name,
      files: files.map do |file|
        repository_file_to_response_file file
      end
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
        owner_name: project.owner_name
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
        owner_name: project.owner_name
      )
    end
  end

  websocket GET, "/projects/:id/notifications", def open_project_notification(socket, ctx)
    user_id = authenticate(ctx)
    project_id = UUID.new ctx.path_parameter "id"
    
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
end
