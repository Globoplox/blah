require "./repositories"
require "./database_repository"

class Repositories::Files::Database < Repositories::Files
  include Repositories::Database

  def initialize(@connection)
  end

  def insert(project_id : UUID, blob_id : UUID?, path : String, author_id : UUID) : UUID | DuplicatePathError
    file_id = UUID.random
    file = {file_id, project_id, blob_id, path, author_id}

    @connection.exec <<-SQL, *file                                                                                                               
      INSERT INTO project_files (
        id, project_id, blob_id, path, author_id, editor_id
      ) VALUES ($1, $2, $3, $4, $5, $5)
    SQL
    # $5 twice is not a typo, editor = author at creation

    file_id
  rescue ex : PQ::PQError
    return DuplicatePathError.new if ex.fields.any? { |field| field.name == :constraint_name && field.message }
    raise ex
  end

  def directory_exists?(path : String) : Bool
    return true if path = "/"
    @connection.scalar(<<-SQL, path).as(Bool)
      SELECT EXISTS(SELECT 1 FROM project_files WHERE path = $1)
    SQL
  end

  def is_directory?(file_id : UUID) : Bool
    @connection.scalar(<<-SQL, file_id).as(Bool)
      SELECT is_directory FROM project_files WHERE id = $1
    SQL
  end
  
  def delete(file_id : UUID)
    path = @connection.scalar(<<-SQL, file_id).as(String)
      SELECT path FROM project_files WHERE id = $1
    SQL

    if path.ends_with? '/'
      @connection.exec <<-SQL, file_id, path
        DELETE FROM project_files 
        WHERE id = $1 OR starts_with(path, $2)
      SQL
    else
      @connection.exec <<-SQL, file_id
        DELETE FROM project_files 
        WHERE id = $1
      SQL
    end
  end
  
  def move(file_id : UUID, to_path : String, editor_id : UUID) : DuplicatePathError?
    @connection.exec <<-SQL, file_id, editor_id, to_path                                                                                                         
      UPDATE project_files SET 
        editor_id = $2,
        file_edited_at = NOW(),
        path = $3
      WHERE id = $1
    SQL
    return
  rescue ex : PQ::PQError
    return DuplicatePathError.new if ex.fields.any? { |field| field.name == :constraint_name && field.message == "project_files_project_id_path_key" }
    raise ex
  end
  
  def edit(file_id : UUID, editor_id : UUID)
    @connection.exec <<-SQL, file_id, editor_id                                                                                                         
      UPDATE project_files SET 
        editor_id = $2,
        file_edited_at = NOW()
      WHERE id = $1
    SQL
  end

  def get_blob_id(file_id : UUID) : UUID?
    @connection.scalar(<<-SQL, file_id).as(UUID?)
      SELECT blob_id FROM project_files WHERE id = $1
    SQL
  end

  def read(file_id : UUID) : File
    File.from_rs(@connection.query <<-SQL, file_id).first
      SELECT 
        project_files.id,
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
      WHERE project_files.id = $1
    SQL
  end

  def read_by_path(project_id : UUID, path : String) : File?
    File.from_rs(@connection.query <<-SQL, path, project_id).first?
      SELECT 
        project_files.id,
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
      WHERE project_files.path = $1 and project_files.project_id = $2
    SQL
  end

  def list(project_id : UUID) : Array(File)
    File.from_rs @connection.query <<-SQL, project_id
      SELECT 
        project_files.id,
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