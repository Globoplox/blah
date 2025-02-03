require "db"
require "pg"
require "log"

module Schema
  extend self

  # abstract struct Migration
  #   abstract def version

  #   def name
  #     {{ @type.name.gsub(/^.+::/, "").stringify.underscore }}
  #   end

  #   macro inherited
  #     def self.schema
  #       Path[__DIR__].basename
  #     end
  #   end

  #   abstract def migrate(database)
  # end
end

require "./migrations/**"

module Schema
  # dir => {version, name, text}
  RAW_MIGRATIONS = {{run "./embed_migration.cr", "#{__DIR__}/migrations"}}

  # dir => Database::Migration.class
  #HANDLED_MIGRATIONS = {{Migration.all_subclasses.reject(&.abstract?).map(&.name)}}.group_by &.schema

  def migrate(database : DB::Database, schema : String)

    database.exec <<-SQL
      CREATE TABLE IF NOT EXISTS migrations (
        schema_name VARCHAR NOT NULL,
        version INT PRIMARY KEY NOT NULL,
        name TEXT NOT NULL,
        finished_at TIMESTAMPTZ NOT NULL
      )
    SQL

    done = database.query_all <<-SQL, schema, as: Int32
      SELECT version FROM migrations WHERE schema_name = $1
    SQL

    # handled_migrations = HANDLED_MIGRATIONS[schema]?.try &.map do |migration_class|
    #   migration = migration_class.new
    #   {migration.version, migration.name, migration}
    # end

    raw_migrations = RAW_MIGRATIONS[schema]?
    #migrations = (handled_migrations && raw_migrations && handled_migrations + raw_migrations) || handled_migrations || raw_migrations
    migrations = raw_migrations
    return unless migrations

    duplicate = migrations.group_by(&.first).select { |_, values| values.size > 1 }

    if duplicate.size > 0
      raise Exception.new "Duplicate migrations versions: #{duplicate}"
    end

    migrations.sort_by(&.first).each do |(version, name, payload)|
      if !done.includes? version
        begin
          Log.info &.emit "Running migration #{version}: #{name}"
          database.transaction do |transaction|
            case payload
            in String    then transaction.connection.as(PG::Connection).exec_all payload
            #in Migration then payload.migrate transaction.connection
            end
            transaction.connection.exec <<-SQL, version, name, Time.utc, schema
              INSERT INTO migrations (version, name, finished_at, schema_name) VALUES ($1, $2, $3, $4)
            SQL
          end
          Log.info &.emit "Migration #{version}: #{name} ran with success"
        rescue ex
          Log.error exception: ex, &.emit "Migration #{version}: #{name} FAILED"
          raise ex
        end
      end
    end
  end
end
