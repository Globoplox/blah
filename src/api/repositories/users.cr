require "./repositories"
require "./database_repository"

# Database based implementation of the user repository.
class Repositories::Users::Database < Repositories::Users
  include Repositories::Database

  def initialize(@connection)
  end

  def insert(
    identifier : String,
    password_hash : String,
    name : String,
    allowed_projects : Int32,
    allowed_blob_size : Int32,
    allowed_concurrent_job : Int32
  ) : UUID | DuplicateNameError | DuplicateIdentifierError
  
    credential_id = UUID.random
    user_id = UUID.random

    @connection.transaction do |transaction|
    
      user = {
        user_id, 
        name, 
        allowed_projects,
        allowed_blob_size,
        allowed_concurrent_job
      }

      transaction.connection.exec <<-SQL, *user                                                                                                               
        INSERT INTO users (
          id, 
          name, 
          allowed_project,                                                                                                                                    
          allowed_blob_size,                                                                                                                                  
          allowed_concurrent_job                                                                                                                            
        ) VALUES ($1, $2, $3, $4, $5)                                                                               
      SQL

      credential = {credential_id, user_id, identifier, password_hash}

      transaction.connection.exec <<-SQL, *credential                                                                                                         
        INSERT INTO credentials  (id, user_id, identifier, password_hash) VALUES ($1, $2, $3, $4)                                                                  
      SQL
    end

    user_id
  rescue ex : PQ::PQError
    return DuplicateNameError.new if ex.fields.any? { |field| field.name == :constraint_name && field.message == "users_name_key" }
    return DuplicateIdentifierError.new if ex.fields.any? { |field| field.name == :constraint_name && field.message == "users_identifier_key" }
    raise ex
  end

  def get_by_identifier_with_credentials(identifier : String) : UserWithCredentials?
    UserWithCredentials.from_rs(@connection.query <<-SQL, identifier).first?                                   
      SELECT                                                                                                                                                  
        credentials.password_hash,                                                                                                                            
        users.id,                                                                                                                                             
        users.name,                                                                                                                                           
        users.allowed_project,                                                                                                                          
        users.allowed_blob_size,                                                                                                                        
        users.allowed_concurrent_job,                                                                                                                  
        users.created_at,                                                                                                                
        credentials.identifier,                                                                                                                                       
        credentials.password_hash,                                                                                                                                       
        credentials.id as credential_id
      FROM credentials
        LEFT JOIN users ON users.id = credentials.user_id                                                                                                    
      WHERE credentials.identifier = $1                                                                                                                            
    SQL
  end

  def read(id : UUID) : User
    User.from_rs(@connection.query <<-SQL, id).first                                  
      SELECT                                                                                                                                                  
        users.id,                                                                                                                                             
        users.name,                                                                                                                                           
        users.allowed_project,                                                                                                                          
        users.allowed_blob_size,                                                                                                                        
        users.allowed_concurrent_job,                                                                                                                  
        users.created_at,
        users.avatar_blob_id      
      FROM users                                                                                                                                                                                                              
      WHERE users.id = $1                                                                                                                            
    SQL
  end

  def get_by_name(name : String) : User?
    User.from_rs(@connection.query <<-SQL, name).first?                                   
      SELECT                                                                                                                                                  
        users.id,                                                                                                                                             
        users.name,                                                                                                                                           
        users.allowed_project,                                                                                                                          
        users.allowed_blob_size,                                                                                                                        
        users.allowed_concurrent_job,                                                                                                                  
        users.created_at,
        users.avatar_blob_id      
      FROM users                                                                                                                                                                                                           
      WHERE users.name = $1                                                                                                                            
    SQL
  end

  def set_avatar(user_id : UUID, blob_id : UUID?)
    @connection.exec <<-SQL, user_id, blob_id
      UPDATE users SET avatar_blob_id = $2 WHERE id = $1
    SQL
  end
end
