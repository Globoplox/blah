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
      property allowed_blob_size : Int32
      property allowed_project : Int32
      property allowed_concurrent_job : Int32
      property allowed_concurrent_tty : Int32
      property created_at : Time
      property credential_id : UUID
      property email : String
      property password_hash : String
    end

    abstract def get_by_email_with_credentials(email : String) : UserWithCredentials?
  end

  abstract class Projects
    
    abstract def insert(
      name : String,
      owner_id : UUID,
      public : Bool,
      description : String?,
      allowed_blob_size : UInt32,
      allowed_file_amount : UInt32
    ) : UUID
  
    class Project
      include DB::Serializable
      property id : UUID
      property name : String
      property owner_id : UUID
      property public : Bool
      property description : String?
      property allowed_blob_size : Int32
      property allowed_file_amount : Int32
      property created_at : Time
      property owner_name : String
    end

    abstract def search_public(query  : String?) : Array(Project)

    abstract def search_owned(owner_id : UUID, query  : String?) : Array(Project)

    abstract def read(id  : UUID) : Project

  end
end