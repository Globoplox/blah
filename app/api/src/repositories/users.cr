require "./repositories"

# Database based implementation of the user repository.
class Repositories::Users::Database < Repositories::Users
  @connexion : DB::Database

  def initialize(@connexion)
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
  ) : UUID
  
    credential_id = UUID.random
    user_id = UUID.random

    @connexion.transaction do |transaction|
    
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
  end

  def get_by_email_with_credentials(email : String) : UserWithCredentials?
    UserWithCredentials.from_rs(@connexion.query <<-SQL, email).first?                                   
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
