# Interfaces for repositories.
module Repositories
  abstract class Users

    abstract def insert(
      email : String,
      password_hash : String,
      name : String,
      tag : String,
      allowed_projects : Int32,
      allowed_blob_size : Int32,
      allowed_concurrent_job : Int32,
      allowed_concurrent_tty : Int32
    ) : UUID

    class UserWithCredentials
      include DB::Serializable
      property id : UUID
      property name : String
      property tag : String
      property avatar_id : UUID?
      property allowed_blob_size : UInt32
      property allowed_project : UInt32
      property allowed_concurrent_job : UInt32
      property allowed_concurrent_tty : UInt32
      property created_at : Time
      property credential_id : UUID
      property email : String
      property password_hash : String
    end

    abstract def get_by_email_with_credentials(email : String) : UserWithCredentials?
  end
end