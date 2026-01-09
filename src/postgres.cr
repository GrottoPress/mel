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

    def self.new(url, namespace = :mel)
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

      return find_due_update(time, count) if delete.nil?
      delete ? find_due_delete(time, count) : find_due_no_delete(time, count)
    end

    def find(count : Int, *, delete : Bool? = false) : Array(String)?
      return if count.zero?

      return find_update(count) if delete.nil?
      delete ? find_delete(count) : find_no_delete(count)
    end

    def find(ids : Indexable, *, delete : Bool = false) : Array(String)?
      return if ids.empty?

      with_transaction do |connection|
        data = connection.query_all <<-SQL, ids.map(&.to_s), as: String
          SELECT data FROM #{tasks_table} WHERE id = ANY($1);
          SQL

        delete(connection, ids) if delete
        data unless data.empty?
      end
    end

    def transaction(& : Transaction -> _)
      with_transaction do |connection|
        yield Transaction.new(self, connection)
      end
    end

    def truncate
      with_connection &.exec <<-SQL
        TRUNCATE TABLE #{tasks_table};
        SQL
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
      with_connection &.exec <<-SQL
        TRUNCATE TABLE #{progress_table};
        SQL
    end

    private def create_tables
      with_transaction do |connection|
        connection.exec <<-SQL
          CREATE TABLE IF NOT EXISTS #{tasks_table} (
            id TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            schedule BIGINT NOT NULL
          );
          SQL

        connection.exec <<-SQL
          CREATE INDEX IF NOT EXISTS idx_#{tasks_table}_schedule
          ON #{tasks_table} (schedule);
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

    private def find_due_delete(time, count)
      sql = <<-SQL
        SELECT id, data FROM #{tasks_table}
        WHERE schedule >= $1 AND schedule <= $2
        ORDER BY schedule LIMIT $3 FOR UPDATE SKIP LOCKED;
        SQL

      with_transaction do |connection|
        ids, data = unpack connection.query_all(
          sql,
          0,
          time.to_unix,
          limit(count),
          as: {id: String, data: String}
        )

        delete(connection, ids)
        data unless data.empty?
      end
    end

    private def find_due_no_delete(time, count)
      sql = <<-SQL
        SELECT data FROM #{tasks_table}
        WHERE schedule >= $1 AND schedule <= $2
        ORDER BY schedule LIMIT $3;
        SQL

      with_transaction do |connection|
        data = connection.query_all(
          sql,
          0,
          time.to_unix,
          limit(count),
          as: String
        )

        data unless data.empty?
      end
    end

    private def find_due_update(time, count)
      sql = <<-SQL
        SELECT id, data FROM #{tasks_table}
        WHERE schedule >= $1 AND schedule <= $2
        ORDER BY schedule LIMIT $3 FOR UPDATE SKIP LOCKED;
        SQL

      with_transaction do |connection|
        to_running(connection, RunPool.fetch)

        ids, data = unpack connection.query_all(
          sql,
          orphan_timestamp,
          time.to_unix,
          limit(count),
          as: {id: String, data: String}
        )

        to_running(connection, ids)
        RunPool.update(ids)

        data unless data.empty?
      end
    end

    private def find_delete(count)
      sql = <<-SQL
        SELECT id, data FROM #{tasks_table} WHERE schedule >= $1
        ORDER BY schedule LIMIT $2 FOR UPDATE SKIP LOCKED;
        SQL

      with_transaction do |connection|
        ids, data = unpack connection.query_all(
          sql,
          0,
          limit(count),
          as: {id: String, data: String}
        )

        delete(connection, ids)
        data unless data.empty?
      end
    end

    private def find_no_delete(count)
      sql = <<-SQL
        SELECT data FROM #{tasks_table} WHERE schedule >= $1
        ORDER BY schedule LIMIT $2;
        SQL

      with_transaction do |connection|
        data = connection.query_all(
          sql,
          0,
          limit(count),
          as: String
        )

        data unless data.empty?
      end
    end

    private def find_update(count)
      sql = <<-SQL
        SELECT id, data FROM #{tasks_table} WHERE schedule >= $1
        ORDER BY schedule LIMIT $2 FOR UPDATE SKIP LOCKED;
        SQL

      with_transaction do |connection|
        to_running(connection, RunPool.fetch)

        ids, data = unpack connection.query_all(
          sql,
          orphan_timestamp,
          limit(count),
          as: {id: String, data: String}
        )

        to_running(connection, ids)
        RunPool.update(ids)

        data unless data.empty?
      end
    end

    private def delete(connection, ids)
      connection.exec <<-SQL, ids.map(&.to_s)
        DELETE FROM #{tasks_table} WHERE id = ANY($1);
        SQL
    end

    private def to_running(connection, ids)
      return if ids.empty?

      connection.exec <<-SQL, running_timestamp, ids.to_a
        UPDATE #{tasks_table} SET schedule = $1 WHERE id = ANY($2);
        SQL
    end

    private def limit(count)
      count > 0 ? count : nil
    end

    private def unpack(values)
      ids = values.map(&.[:id])
      data = values.map(&.[:data])

      {ids, data}
    end

    private def with_transaction(&)
      with_connection &.transaction do |transaction|
        yield transaction.connection
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
          INSERT INTO #{@postgres.tasks_table} (id, data, schedule)
          VALUES ($1, $2, $3)
          ON CONFLICT (id) DO NOTHING;
          SQL
      end

      def update(task : Task)
        time = task.retry_time || task.time

        @connection.exec <<-SQL, task.id, task.to_json, time.to_unix
          INSERT INTO #{@postgres.tasks_table} (id, data, schedule)
          VALUES ($1, $2, $3)
          ON CONFLICT (id) DO UPDATE SET data = $2, schedule = $3;
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
