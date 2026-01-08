require "pg"

require "./mel"

module Mel
  struct Postgres
    include Store

    getter :client, :progress_table, :tasks_table

    def initialize(
      @client : DB::Database,
      @namespace : Symbol | String = :mel
    )
      @progress_table = "#{@namespace}_progress"
      @tasks_table = "#{@namespace}_tasks"

      create_tables
    end

    def self.new(url, namespace = :mel, *, setup = false)
      create_database(url) if setup

      new DB.open(url), namespace
    end

    def self.create_database(url : String)
      create_database URI.parse(url)
    end

    def self.create_database(url : URI)
      db_name = url.path.lchop('/')

      default_url = URI.parse(url.to_s)
      default_url.path = "/postgres"

      DB.connect(default_url) do |connection|
        create_database(connection, db_name)
      end
    end

    def self.delete_database(url : String)
      delete_database URI.parse(url)
    end

    def self.delete_database(url : URI)
      db_name = url.path.lchop('/')

      default_url = URI.parse(url.to_s)
      default_url.path = "/postgres"

      DB.connect(default_url) do |connection|
        delete_database(connection, db_name)
      end
    end

    def find_due(
      at time = Time.local,
      count : Int = -1, *,
      delete : Bool? = false
    ) : Array(String)?
      return if count.zero?

      running_select_sql = <<-SQL
        SELECT id, data FROM #{tasks_table} WHERE score >= $1 AND score <= $2
        ORDER BY score LIMIT $3 FOR UPDATE SKIP LOCKED;
        SQL

      select_sql = <<-SQL
        SELECT data FROM #{tasks_table} WHERE score >= $1 AND score <= $2
        ORDER BY score LIMIT $3;
        SQL

      limit = count > 0 ? count : nil

      with_transaction do |connection|
        if delete.nil?
          to_running(connection, RunPool.fetch)

          values = connection.query_all(
            running_select_sql,
            orphan_score,
            time.to_unix,
            limit,
            as: {id: String, data: String}
          )

          data = values.map(&.[:data])
          ids = values.map(&.[:id])

          to_running(connection, ids)
          RunPool.update(ids)

          next data.empty? ? nil : data
        end

        data = connection.query_all(
          select_sql,
          0,
          time.to_unix,
          limit,
          as: String
        )

        data unless data.empty?
      end
    end

    def find(count : Int, *, delete : Bool? = false) : Array(String)?
      return if count.zero?

      running_select_sql = <<-SQL
        SELECT id, data FROM #{tasks_table} WHERE score >= $1
        ORDER BY score LIMIT $2 FOR UPDATE SKIP LOCKED;
        SQL

      select_sql = <<-SQL
        SELECT data FROM #{tasks_table} WHERE score >= $1
        ORDER BY score LIMIT $2;
        SQL

      limit = count > 0 ? count : nil

      with_transaction do |connection|
        if delete.nil?
          to_running(connection, RunPool.fetch)

          values = connection.query_all(
            running_select_sql,
            orphan_score,
            limit,
            as: {id: String, data: String}
          )

          data = values.map(&.[:data])
          ids = values.map(&.[:id])

          to_running(connection, ids)
          RunPool.update(ids)

          next data.empty? ? nil : data
        end

        data = connection.query_all(select_sql, 0, limit, as: String)
        data unless data.empty?
      end
    end

    def find(ids : Indexable, *, delete : Bool = false) : Array(String)?
      return if ids.empty?

      with_transaction do |connection|
        data = connection.query_all <<-SQL, ids.map(&.to_s), as: String
          SELECT data FROM #{tasks_table} WHERE id = ANY($1);
          SQL

        if delete
          connection.exec <<-SQL, ids.map(&.to_s)
            DELETE FROM #{tasks_table} WHERE id = ANY($1);
            SQL
        end

        data unless data.empty?
      end
    end

    def transaction(& : Transaction -> _)
      with_transaction do |connection|
        yield Transaction.new(self, connection)
      end
    end

    def truncate
      with_connection do |connection|
        connection.exec <<-SQL
          TRUNCATE TABLE #{tasks_table};
          SQL
      end
    end

    def get_progress(ids : Indexable) : Array(String)?
      return if ids.empty?

      with_transaction do |connection|
        connection.exec <<-SQL
          DELETE FROM #{progress_table}
          WHERE expires_at IS NOT NULL AND expires_at <= CURRENT_TIMESTAMP;
          SQL

        data = connection.query_all <<-SQL, ids.map(&.to_s), as: String
          SELECT data FROM #{progress_table}
          WHERE id = ANY($1)
          AND (expires_at IS NULL OR expires_at > CURRENT_TIMESTAMP);
          SQL

        data unless data.empty?
      end
    end

    def truncate_progress
      with_connection do |connection|
        connection.exec <<-SQL
          TRUNCATE TABLE #{progress_table};
          SQL
      end
    end

    private def create_tables
      with_transaction do |connection|
        connection.exec <<-SQL
          CREATE TABLE IF NOT EXISTS #{tasks_table} (
            id TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            score BIGINT NOT NULL
          );
          SQL

        connection.exec <<-SQL
          CREATE INDEX IF NOT EXISTS idx_#{tasks_table}_score
          ON #{tasks_table} (score);
          SQL

        connection.exec <<-SQL
          CREATE TABLE IF NOT EXISTS #{progress_table} (
            id TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            expires_at TIMESTAMP WITH TIME ZONE
          );
          SQL
      end
    end

    private def to_running(connection, ids)
      return if ids.empty?

      connection.exec <<-SQL, running_score, ids.to_a
        UPDATE #{tasks_table} SET score = $1 WHERE id = ANY($2);
        SQL
    end

    private def with_transaction(&)
      with_connection do |connection|
        connection.transaction { |transaction| yield transaction.connection }
      end
    end

    private def with_connection(&)
      client.retry do
        client.using_connection { |connection| yield connection }
      end
    end

    private def self.create_database(connection, name)
      clean_name = PG::EscapeHelper.escape_identifier(name)

      connection.exec <<-SQL
        CREATE DATABASE #{clean_name};
        SQL
    rescue error : PQ::PQError
      message = error.message.to_s
      raise error unless message.includes?(%("#{name}" already exists))
    end

    private def self.delete_database(connection, name)
      clean_name = PG::EscapeHelper.escape_identifier(name)

      connection.exec <<-SQL
        DROP DATABASE IF EXISTS #{clean_name};
        SQL
    end

    struct Transaction
      include Mel::Transaction

      def initialize(@postgres : Postgres, @connection : DB::Connection)
      end

      def create(task : Task)
        @connection.exec <<-SQL, task.id, task.to_json, task.time.to_unix
          INSERT INTO #{@postgres.tasks_table} (id, data, score)
          VALUES ($1, $2, $3)
          ON CONFLICT (id) DO NOTHING;
          SQL
      end

      def update(task : Task)
        time = task.retry_time || task.time

        @connection.exec <<-SQL, task.id, task.to_json, time.to_unix
          INSERT INTO #{@postgres.tasks_table} (id, data, score)
          VALUES ($1, $2, $3)
          ON CONFLICT (id) DO UPDATE SET data = $2, score = $3;
          SQL
      end

      def set_progress(id : String, value : Int, description : String)
        report = Progress::Report.new(id, description, value)
        expiry = Mel.settings.progress_expiry.try(&.from_now)

        @connection.exec <<-SQL, id, report.to_json, expiry
          INSERT INTO #{@postgres.progress_table} (id, data, expires_at)
          VALUES ($1, $2, $3)
          ON CONFLICT (id) DO UPDATE SET data = $2, expires_at = $3;
          SQL
      end
    end
  end
end
