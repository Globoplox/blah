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
      LEFT JOIN user_project_acls ON user_project_acls.project_id = projects.id AND user_id = $2
      WHERE projects.owner_id = $2 OR user_project_acls.project_id IS NOT NULL
      ORDER BY 
        LEVENSHTEIN(projects.name, COALESCE($1, projects.name)) DESC, 
        projects.created_at DESC
    SQL
  end

  def count_for_user(user_id : UUID) : Int64
    @connection.scalar(<<-SQL, user_id).as(Int64)
      SELECT COUNT(id) FROM projects WHERE projects.owner_id = $1
    SQL
  end

  def user_can_rw(project_id : UUID, user_id : UUID) : {Bool, Bool}
    @connection.query_one(<<-SQL, project_id, user_id, as: {Bool, Bool})
      SELECT 
        (projects.public OR projects.owner_id = $2 OR user_project_acls.project_id IS NOT NULL) as can_red,  
        (projects.owner_id = $2 OR user_project_acls.can_write) as can_write
      FROM projects
      LEFT JOIN user_project_acls ON user_project_acls.project_id = $1 AND user_id = $2
      WHERE projects.id = $1
    SQL
  end

  def acl(project_id : UUID, query : String? = nil) : Array(Acl)
    query = nil if query && query.empty?
    if query
      Acl.from_rs @connection.query <<-SQL, project_id, query
        SELECT
          users.id as user_id,
          users.name as user_name,
          COALESCE(user_project_acls.can_write, false) as can_write,
          users.avatar_blob_id,
          (user_project_acls.project_id IS NOT NULL) as can_read
        FROM users 
        LEFT JOIN user_project_acls ON user_project_acls.project_id = $1 AND user_project_acls.user_id = users.id 
        ORDER BY LEVENSHTEIN(users.name, $2) DESC
        LIMIT 10
      SQL
    else
      Acl.from_rs @connection.query <<-SQL, project_id
        SELECT
          user_project_acls.user_id,
          users.name as user_name,
          user_project_acls.can_write,
          users.avatar_blob_id,
          true as can_read
        FROM user_project_acls
        JOIN users ON user_project_acls.user_id = users.id
        WHERE project_id = $1
      SQL
    end
  end

  def set_acl(project_id : UUID, user_id : UUID, can_read : Bool, can_write : Bool)
    raise "Bad acl: can_read cannot be false if can_write is true" if !can_read && can_write
    if !can_read
      @connection.exec <<-SQL, project_id, user_id
        DELETE FROM user_project_acls WHERE project_id = $1 AND user_id = $2
      SQL
    else
      @connection.exec <<-SQL, project_id, user_id, can_write
        INSERT INTO user_project_acls 
          (project_id, user_id, can_write) 
        VALUES 
          ($1, $2, $3)
        ON CONFLICT (project_id, user_id) DO UPDATE SET can_write = $3;
      SQL
    end
  end

  def set_avatar(project_id : UUID, blob_id : UUID?)
    @connection.exec <<-SQL, project_id, blob_id
      UPDATE projects SET blob_id = $2 WHERE id = $1
    SQL
  end

end
