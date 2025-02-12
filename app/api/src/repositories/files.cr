require "./repositories"
require "./database_repository"

class Repositories::Files::Database < Repositories::Files
  include Repositories::Database

  def initialize(@connection)
  end

  def insert(project_id : UUID, blob_id : UUID?, path : String, author_id : UUID) : DuplicatePathError?
    file = {project_id, blob_id, path, author_id}

    @connection.exec <<-SQL, *file                                                                                                               
      INSERT INTO project_files (
        project_id, blob_id, path, author_id, editor_id
      ) VALUES ($1, $2, $3, $4, $4)
    SQL

    return
  rescue ex : PQ::PQError
    return DuplicatePathError.new if ex.fields.any? { |field| field.name == :constraint_name && field.message == "project_files_project_id_path_key"}
    raise ex
  end

  def is_directory?(project_id : UUID, path : String) : Bool
    @connection.query_one?(<<-SQL, project_id, path, as: Bool?) || false
      SELECT is_directory FROM project_files WHERE project_id = $1 AND path = $2
    SQL
  end
  
  def delete(project_id : UUID, path : String)
    if path.ends_with? '/'
      @connection.exec <<-SQL, project_id, path
        DELETE FROM project_files 
        WHERE project_id = $1 AND starts_with(path, $2)
      SQL
    else
      @connection.exec <<-SQL, project_id, path
        DELETE FROM project_files 
        WHERE project_id = $1 AND path = $2
      SQL
    end
  end
  
  def move(project_id : UUID, path : String, to_path : String, editor_id : UUID) : DuplicatePathError?
    @connection.exec <<-SQL, project_id, path, editor_id, to_path                                                                                                         
      UPDATE project_files SET 
        editor_id = $3,
        file_edited_at = NOW(),
        path = $4
      WHERE  project_id = $1 AND path = $2
    SQL
    return
  rescue ex : PQ::PQError
    return DuplicatePathError.new if ex.fields.any? { |field| field.name == :constraint_name && field.message == "project_files_project_id_path_key" }
    raise ex
  end
  
  def edit(project_id : UUID, path : String, editor_id : UUID)
    @connection.exec <<-SQL, project_id, path, editor_id                                                                                                         
      UPDATE project_files SET 
        editor_id = $3,
        file_edited_at = NOW()
      WHERE  project_id = $1 AND path = $2
    SQL
  end

  def get_blob_id(project_id : UUID, path : String) : UUID?
    @connection.scalar(<<-SQL, project_id, path).as(UUID?)
      SELECT blob_id FROM project_files WHERE project_id = $1 AND path = $2
    SQL
  end

  def read(project_id : UUID, path : String) : File?
    File.from_rs(@connection.query <<-SQL, project_id, path).first?
      SELECT 
        project_files.project_id,
        project_files.path,
        project_files.author_id,
        project_files.editor_id,
        project_files.blob_id,
        project_files.created_at,
        project_files.file_edited_at,
        project_files.is_directory,
        author_users.name as author_name,
        editor_users.name as editor_name
      FROM project_files
      LEFT JOIN users author_users ON author_users.id = project_files.author_id
      LEFT JOIN users editor_users ON editor_users.id = project_files.editor_id
      WHERE project_files.project_id = $1 AND project_files.path = $2
    SQL
  end

  def list(project_id : UUID) : Array(File)
    File.from_rs @connection.query <<-SQL, project_id
      SELECT 
        project_files.project_id,
        project_files.path,
        project_files.author_id,
        project_files.editor_id,
        project_files.blob_id,
        project_files.created_at,
        project_files.file_edited_at,
        project_files.is_directory,
        author_users.name as author_name,
        editor_users.name as editor_name
      FROM project_files
      LEFT JOIN users author_users ON author_users.id = project_files.author_id
      LEFT JOIN users editor_users ON editor_users.id = project_files.editor_id
      WHERE project_id = $1
    SQL
  end

end