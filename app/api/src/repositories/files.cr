require "./repositories"
require "./database_repository"

class Repositories::Files::Database < Repositories::Files
  include Repositories::Database

  def initialize(@connection)
  end

  def insert(project_id : UUID, blob_id : UUID?, path : String, author_id : UUID) : UUID
    file_id = UUID.random
    file = {file_id, project_id, blob_id, path, author_id}

    @connection.exec <<-SQL, *file                                                                                                               
      INSERT INTO project_files (
        id, project_id, blob_id, path, author_id, editor_id
      ) VALUES ($1, $2, $3, $4, $5, $5)
    SQL
    # $5 twice is not a typo, editor = author at creation

    file_id
  end
  
  def delete(file_id : UUID)
    @connection.exec <<-SQL, file_id
      DELETE FROM project_files WHERE id = $1
    SQL
  end
  
  def move(project_id : UUID, from_path : String, to_path : String, editor_id : UUID)
    @connection.exec <<-SQL, project_id, from_path, editor_id, to_path                                                                                                         
      UPDATE project_files SET 
        editor_id = $3,
        file_edited_at = NOW(),
        path = $4
      WHERE project_id = $1 AND path = $2
    SQL
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
      SELECT blob_id FROM project_file WHERE id = $1
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