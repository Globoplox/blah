# Interfaces for repositories.
module Repositories

  abstract class Users

    class DuplicateNameError
    end

    class DuplicateEmailError
    end

    abstract def insert(
      email : String,
      password_hash : String,
      name : String,
      tag : String,
      allowed_projects : Int32,
      allowed_blob_size : Int32,
      allowed_concurrent_job : Int32,
      allowed_concurrent_tty : Int32
    ) : UUID | DuplicateNameError | DuplicateEmailError

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

    class User
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
    end

    abstract def read(id : UUID) : User
    abstract def get_by_name(name : String) : User?
  end

  abstract class Projects
    
    class DuplicateNameError
    end

    abstract def insert(
      name : String,
      owner_id : UUID,
      public : Bool,
      description : String?,
      allowed_blob_size : UInt32,
      allowed_file_amount : UInt32
    ) : UUID | DuplicateNameError
  
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
    abstract def get_by_user_and_name(user_id : UUID, name : String) : Project?

  end

  abstract class Blobs
    abstract def insert(content_type : String, size : Int32) : UUID
    abstract def delete(blob_id : UUID,)
    abstract def update(blob_id : UUID, size : Int32)
  end

  abstract class Files

    class DuplicatePathError
    end

    class File
      include DB::Serializable
      property project_id : UUID
      property path : String
      property author_id : UUID
      property editor_id : UUID
      property blob_id : UUID?
      property created_at : Time
      property file_edited_at : Time
      property author_name : String
      property editor_name : String
      property is_directory : Bool
    end

    abstract def insert(project_id : UUID, blob_id : UUID?, path : String, author_id : UUID) : DuplicatePathError?
    abstract def delete(project_id : UUID, path : String)
    abstract def move(project_id : UUID, path : String, to_path : String, editor_id : UUID) : DuplicatePathError?
    abstract def edit(project_id : UUID, path : String, editor_id : UUID)
    abstract def list(project_id : UUID) : Array(File)
    abstract def get_blob_id(project_id : UUID, path : String) : UUID?
    abstract def directory_exists?(project_id : UUID, path : String) : Bool
    abstract def is_directory?(project_id : UUID, path : String) : Bool
    abstract def read(project_id : UUID, path : String) : File?
  end
end