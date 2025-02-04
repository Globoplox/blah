require "./repositories"

# Database based implementation of the user repository.
class Repositories::Projects::Database < Repositories::Projects
  @connexion : DB::Database

  def initialize(@connexion)
  end

  def insert(
    name : String,
    owner_id : UUID,
    public : Bool,
    description : String?,
    allowed_blob_size : UInt32,
    allowed_file_amount : UInt32
  ) : UUID

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

    @connexion.exec <<-SQL, *project                                                                                                               
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
  end

  def read(id  : UUID) : Project
    Project.from_rs(@connexion.query(<<-SQL, id)).first
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
      END
    SQL
  end

  def search_public(query  : String?) : Array(Project)
    Project.from_rs @connexion.query <<-SQL, query
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
    Project.from_rs @connexion.query <<-SQL, query, owner_id
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
end
