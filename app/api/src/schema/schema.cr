require "db"
require "pg"

module Schema
  extend self

  abstract struct Migration
    abstract def version

    def name
      {{ @type.name.gsub(/^.+::/, "").stringify.underscore }}
    end

    abstract def migrate(database)
  end
end

module Schema

  RAW_MIGRATIONS = {{run "./tool/compile_time_text_migrations.cr", "#{__DIR__}/migrations"}}

  # HANDLED_MIGRATIONS = {{Migration.all_subclasses.reject(&.abstract?).map(&.name)}}

  delegate :close, :query_one, :query_one?, :query_all, :exec, :transaction, :query, to: connexion

  @@database : DB::Database?

  def connexion
    @@database.not_nil!
  end

  def init
    @@database = DB.open ENV["DATABASE_URI"]

    connexion.exec <<-SQL
      CREATE TABLE IF NOT EXISTS migrations (
        version INT PRIMARY KEY NOT NULL,
        name TEXT NOT NULL,
        finished_at TIMESTAMPTZ NOT NULL
      )
    SQL

    done = connexion.query_all <<-SQL, as: Int32
      SELECT version FROM migrations
    SQL

    # handled_migrations = HANDLED_MIGRATIONS.map do |migration_class|
    #   migration = migration_class.new
    #   {migration.version, migration.name, migration}
    # end

    raw_migrations = RAW_MIGRATIONS
    migrations =  raw_migrations # + handled_migrations

    duplicate = migrations.group_by(&.first).select { |_, values| values.size > 1 }

    if duplicate.size > 0
      raise Exception.new "Duplicate migrations versions: #{duplicate}"
    end

    migrations.sort_by(&.first).each do |(version, name, payload)|
      if !done.includes? version
        begin
          Log.info &.emit "Running migration #{version}: #{name}"
          connexion.transaction do |transaction|
            case payload
            in String    then transaction.connection.as(PG::Connection).exec_all payload
            in Migration then payload.migrate transaction.connection
            end
            transaction.connection.exec <<-SQL, version, name, Time.utc
              INSERT INTO migrations (version, name, finished_at) VALUES ($1, $2, $3)
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

require "./*"