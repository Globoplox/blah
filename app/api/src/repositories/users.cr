require "./repositories"
require "./database_repository"

# Database based implementation of the user repository.
class Repositories::Users::Database < Repositories::Users
  include Repositories::Database

  def initialize(@connection)
  end

  def insert(
    email : String,
    password_hash : String,
    name : String,
    tag : String,
    allowed_projects : Int32,
    allowed_blob_size : Int32,
    allowed_concurrent_job : Int32,
    allowed_concurrent_tty : Int32
  ) : UUID | DuplicateNameError | DuplicateEmailError
  
    credential_id = UUID.random
    user_id = UUID.random

    @connection.transaction do |transaction|
    
      user = {
        user_id, 
        name, 
        tag, 
        allowed_projects,
        allowed_blob_size,
        allowed_concurrent_job,
        allowed_concurrent_tty 
      }

      transaction.connection.exec <<-SQL, *user                                                                                                               
        INSERT INTO users (
          id, 
          name, 
          tag, 
          allowed_project,                                                                                                                                    
          allowed_blob_size,                                                                                                                                  
          allowed_concurrent_job,                                                                                                                             
          allowed_concurrent_tty    
        ) VALUES ($1, $2, $3, $4, $5, $6, $7)                                                                               
      SQL

      credential = {credential_id, user_id, email, password_hash}

      transaction.connection.exec <<-SQL, *credential                                                                                                         
        INSERT INTO credentials  (id, user_id, email, password_hash) VALUES ($1, $2, $3, $4)                                                                  
      SQL
    end

    user_id
  rescue ex : PQ::PQError
    return DuplicateNameError.new if ex.fields.any? { |field| field.name == :constraint_name && field.message == "users_name_key" }
    return DuplicateEmailError.new if ex.fields.any? { |field| field.name == :constraint_name && field.message == "users_email_key" }
    raise ex
  end

  def get_by_email_with_credentials(email : String) : UserWithCredentials?
    UserWithCredentials.from_rs(@connection.query <<-SQL, email).first?                                   
      SELECT                                                                                                                                                  
        credentials.password_hash,                                                                                                                            
        users.id,                                                                                                                                             
        users.name,                                                                                                                                           
        users.tag,                                                                                                                                            
        users.allowed_project,                                                                                                                          
        users.allowed_blob_size,                                                                                                                        
        users.allowed_concurrent_job,                                                                                                                  
        users.allowed_concurrent_tty,   
        users.created_at,                                                                                                                
        credentials.email,                                                                                                                                       
        credentials.password_hash,                                                                                                                                       
        credentials.id as credential_id                                                                                                                                    
      FROM credentials
        LEFT JOIN users ON users.id = credentials.user_id                                                                                                    
      WHERE credentials.email = $1                                                                                                                            
    SQL
  end
end
