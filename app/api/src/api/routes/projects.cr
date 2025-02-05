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

    Validations.validate! do
      accumulate "name", check_project_name project.name
      if description = project.description
        accumulate "description", check_project_description description 
      end
    end

    project_id = @projects.insert(
      name: project.name,
      owner_id: user_id,
      public: project.public,
      description: project.description,
      allowed_blob_size: 1_000_000,
      allowed_file_amount: 50
    )

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
      property path : String
      property content_uri : String
      property created_at : Time
      property file_edited_at : Time
      property author_name : String
      property editor_name : String

      def initialize(@path, @content_uri, @created_at, @file_edited_at, @author_name, @editor_name)
      end
    end

    def initialize(@id, @name, @public, @description, @created_at, @owner_name, @files = nil)
    end
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
        Response::Project::File.new(
          path: file.path,
          created_at: file.created_at,
          file_edited_at: file.file_edited_at,
          author_name: file.author_name,
          editor_name: file.editor_name,
          content_uri: @storage.uri(file.blob_id.to_s)
        )
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
end
