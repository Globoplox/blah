require "./repositories"
require "./database_repository"

class Repositories::Blobs::Database < Repositories::Blobs
  include Repositories::Database

  def initialize(@connection)
  end

  def insert(content_type : String, size : Int32) : UUID
    blob_id = UUID.random
    blob = {blob_id, content_type, size}

    @connection.exec <<-SQL, *blob                                                                                                               
      INSERT INTO blobs (id, content_type, size) VALUES ($1, $2, $3)                                                                               
    SQL
  end

  def delete(blob_id : UUID)
    @connection.exec <<-SQL, blob_id                                                                                                           
      DELETE FROM blobs WHERE id = $1                                                                               
    SQL
  end
end
