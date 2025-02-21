struct Migrations::Seed < Schema::Migration
  property version = 2

  def migrate(database, storage)

    pp Dir.current
    pp Dir.children(Dir.current)
    pp Dir.children(Path[Dir.current, "migrations"])

    path = Path["migrations/main/02__seed"]
    Dir.children(path).each do |user|
      user_path = Path[path, user]

      Log.info &.emit "Seeding user #{user}"

      user_id = UUID.random
      name = user
      tag = "0000"
      allowed_projects = 10
      allowed_blob_size = 10_000_000
      allowed_concurrent_job = 0

      if File.exists? Path[user_path, "AVATAR.jpg"]
        avatar = File.read(Path[user_path, "AVATAR.jpg"])

        avatar_blob_id = UUID.random
        content_type = "image/jpeg"
        size = avatar.bytesize
        blob = {avatar_blob_id, content_type, size}
    
        database.exec <<-SQL, *blob                                                                                                               
          INSERT INTO blobs (id, content_type, size) VALUES ($1, $2, $3)                                                                               
        SQL

        storage.put(
          data: avatar,
          mime: content_type, 
          name: avatar_blob_id.to_s,
          acl: Storage::ACL::Private
        )
      else 
        avatar_blob_id = nil
      end

      user_data = {
        user_id, 
        name, 
        tag, 
        allowed_projects,
        allowed_blob_size,
        allowed_concurrent_job,
        avatar_blob_id
      }

      database.exec <<-SQL, *user_data                                                                                                              
        INSERT INTO users (
          id, 
          name, 
          tag, 
          allowed_project,                                                                                                                                    
          allowed_blob_size,                                                                                                                                  
          allowed_concurrent_job,
          avatar_blob_id                                                                                                                         
        ) VALUES ($1, $2, $3, $4, $5, $6, $7)
      SQL

      Dir.children(user_path).each do |project|
        project_path = Path[user_path, project]
        next if Path[project_path].basename == "AVATAR.jpg"

        Log.info &.emit "Seeding project #{user}/#{project}"

        project_id = UUID.random    
        name = project
        public = true
        description = File.read(Path[project_path, "DESCRIPTION"])
        owner_id = user_id
        allowed_file_amount = 100
        allowed_blob_size = 10_000_000

        if File.exists? Path[project_path, "AVATAR.jpg"]
          avatar = File.read(Path[project_path, "AVATAR.jpg"])
  
          avatar_blob_id = UUID.random
          content_type = "image/jpeg"
          size = avatar.bytesize
          blob = {avatar_blob_id, content_type, size}
      
          database.exec <<-SQL, *blob                                                                                                               
            INSERT INTO blobs (id, content_type, size) VALUES ($1, $2, $3)                                                                               
          SQL
  
          storage.put(
            data: avatar,
            mime: content_type, 
            name: avatar_blob_id.to_s,
            acl: Storage::ACL::Private
          )
        else 
          avatar_blob_id = nil
        end

        project_data = {
          project_id, 
          name, 
          public,
          description,
          owner_id, 
          allowed_file_amount,
          allowed_blob_size,
          avatar_blob_id
        }

        database.exec <<-SQL, *project_data                                                                                                           
          INSERT INTO projects (
            id, 
            name, 
            public,
            description, 
            owner_id,                                                                                                                                    
            allowed_file_amount,                                                                                                                                  
            allowed_blob_size,
            avatar_blob_id
          ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)                                                                               
        SQL

        Dir["#{project_path}/**"].each do |file|
          file_name = Path[file].relative_to project_path
          next if Path[file_name].basename == "DESCRIPTION"
          next if Path[file_name].basename == "AVATAR.jpg"

          Log.info &.emit "Seeding file #{user}/#{project}/#{file_name}"

          content = File.read(file)

          blob_id = UUID.random
          content_type = "plain/text"
          size = content.bytesize
          blob = {blob_id, content_type, size}
      
          database.exec <<-SQL, *blob                                                                                                               
            INSERT INTO blobs (id, content_type, size) VALUES ($1, $2, $3)                                                                               
          SQL

          storage.put(
            data: content,
            mime: content_type, 
            name: blob_id.to_s,
            acl: Storage::ACL::Private
          )

          author_id = user_id
          file = {project_id, blob_id, "/#{file_name}", author_id}
          database.exec <<-SQL, *file                                                                                                               
            INSERT INTO project_files (
              project_id, blob_id, path, author_id, editor_id
            ) VALUES ($1, $2, $3, $4, $4)
          SQL

        end
      end
    end 
  end
end