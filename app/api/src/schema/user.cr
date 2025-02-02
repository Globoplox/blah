module Schema
  
  def register_user_credentials(
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
    user_quota_id = UUID.random
    user_id = UUID.random

    connexion.transaction do |transaction|
      quota = {
        user_quota_id, 
        0, 
        allowed_projects, 
        allowed_blob_size, 
        allowed_concurrent_job, 
        allowed_concurrent_tty
      }

      transaction.connection.exec <<-SQL, *quota
        INSERT INTO user_quotas  (
          id, 
          blob_size_sum, 
          allowed_project, 
          allowed_blob_size, 
          allowed_concurrent_job, 
          allowed_concurrent_tty
        ) VALUES ($1, $2, $3, $4, $5, $6)
      SQL

      user = {user_id, name, tag, user_quota_id }

      transaction.connection.exec <<-SQL, *user
        INSERT INTO users (id, name, tag, quota_id) VALUES ($1, $2, $3, $4, $5)
      SQL

      credential = {credential_id, user_id, email, password_hash}

      transaction.connection.exec <<-SQL, *credential
        INSERT INTO credentials  (id, user_id, email, password_hash) VALUES ($1, $2, $3, $4)
      SQL

    end

    user_id
  end

  alias Quota = {
    id: UUID,
    blob_size_sum: Int32,
    allowed_projects: Int32,
    allowed_blob_size: Int32,
    allowed_concurrent_job: Int32,
    allowed_concurrent_tty: Int32
  }
  
  alias UserPerCredential = {
    hash: String, 
    id: UUID, 
    name: String, 
    tag: String, 
    quota: Quota
  }

  def get_user_by_credentials(email : String): UserPerCredential? 
    row = connexion.query_one? <<-SQL, email, as: {String, UUID, String, String, UUID, Int32, Int32, Int32, Int32, Int32}
      SELECT 
        credentials.password_hash,
        users.id,
        users.name,
        users.tag,
        users.quota_id,
        user_quotas.blob_size_sum,
        user_quotas.allowed_project,
        user_quotas.allowed_blob_size,
        user_quotas.allowed_concurrent_jobs,
        user_quotas.allowed_concurrent_ttys
      FROM credentials
        LEFT JOIN users ON users.id = crendentials.user_id
        LEFT JOIN user_quotas ON user_quotas.id = users.quota_id
      WHERE credentials.email = $1
    SQL
  
    if row
      hash, user_id, name, tag, quota_id, blob_sum, project, blob, job, tty = row
      {
        hash: hash,
        id: user_id, 
        name: name,
        tag: tag,
        quota: {
          id: quota_id,
          blob_size_sum: blob_sum,
          allowed_projects: project,
          allowed_blob_size: blob,
          allowed_concurrent_job: job,
          allowed_concurrent_tty: tty
        }
      }
    end
  end

end