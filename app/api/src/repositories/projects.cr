require "./repositories"
require "./database_repository"

# Database based implementation of the user repository.
class Repositories::Projects::Database < Repositories::Projects
  include Repositories::Database

  def initialize(@connection)
  end

  def insert(
    name : String,
    owner_id : UUID,
    public : Bool,
    description : String?,
    allowed_blob_size : UInt32,
    allowed_file_amount : UInt32
  ) : UUID  | DuplicateNameError

    project_id = UUID.random    
    
    project = {
      project_id, 
      name, 
      public,
      description,
      owner_id, 
      allowed_file_amount,
      allowed_blob_size,
    }

    @connection.exec <<-SQL, *project                                                                                                               
      INSERT INTO projects (
        id, 
        name, 
        public,
        description, 
        owner_id,                                                                                                                                    
        allowed_file_amount,                                                                                                                                  
        allowed_blob_size    
      ) VALUES ($1, $2, $3, $4, $5, $6, $7)                                                                               
    SQL

    project_id
  rescue ex : PQ::PQError
    return DuplicateNameError.new if ex.fields.any? { |field| field.name == :constraint_name && field.message == "projects_owner_id_name_key" }
    raise ex
  end

  def read(id  : UUID) : Project
    Project.from_rs(@connection.query(<<-SQL, id)).first
      SELECT 
        projects.id,
        projects.name,
        projects.public,
        projects.description,
        projects.owner_id,
        projects.allowed_file_amount,
        projects.allowed_blob_size,
        projects.created_at,
        users.name as owner_name
      FROM projects
      LEFT JOIN users ON users.id = projects.owner_id
      WHERE projects.id = $1
    SQL
  end

  def get_by_user_and_name(user_id : UUID, name : String) : Project?
    Project.from_rs(@connection.query(<<-SQL, user_id, name)).first?
      SELECT 
        projects.id,
        projects.name,
        projects.public,
        projects.description,
        projects.owner_id,
        projects.allowed_file_amount,
        projects.allowed_blob_size,
        projects.created_at,
        users.name as owner_name
      FROM projects
      LEFT JOIN users ON users.id = projects.owner_id
      WHERE projects.owner_id = $1 AND projects.name = $2
    SQL
    
  end

  def search_public(query  : String?) : Array(Project)
    Project.from_rs @connection.query <<-SQL, query
      SELECT 
        projects.id,
        projects.name,
        projects.public,
        projects.description,
        projects.owner_id,
        projects.allowed_file_amount,
        projects.allowed_blob_size,
        projects.created_at,
        users.name as owner_name
      FROM projects
      LEFT JOIN users ON users.id = projects.owner_id
      WHERE projects.public is true
      ORDER BY CASE 
        WHEN $1 IS NULL THEN NULL
        ELSE LEVENSHTEIN(projects.name, $1)
      END DESC, projects.created_at DESC
    SQL
  end

  def search_owned(owner_id : UUID, query  : String?) : Array(Project)
    Project.from_rs @connection.query <<-SQL, query, owner_id
      SELECT 
        projects.id,
        projects.name,
        projects.public,
        projects.description,
        projects.owner_id,
        projects.allowed_file_amount,
        projects.allowed_blob_size,
        projects.created_at,
        users.name as owner_name
      FROM projects
      LEFT JOIN users ON users.id = projects.owner_id
      WHERE projects.owner_id = $2
      ORDER BY 
        LEVENSHTEIN(projects.name, COALESCE($1, projects.name)) DESC, 
        projects.created_at DESC
    SQL
  end

  def count_for_user(user_id : UUID) : Int64
    @connection.scalar(<<-SQL, user_id).as(Int64)
      SELECT COUNT(id) FROM projects WHERE projects.user_id = $1
    SQL
  end

end
