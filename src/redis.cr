require "redis"

require "./mel"

module Mel
  class Redis
    include Store

    private LUA = <<-'LUA'
      local function scores_ids(ids, score)
        local results = {}

        for _, value in ipairs(ids) do
          table.insert(results, score)
          table.insert(results, value)
        end

        return results
      end

      local unpack = table.unpack or unpack
      local ids = redis.call('ZRANGEBYSCORE', KEYS[1], 0, ARGV[1], 'LIMIT', 0, ARGV[2])

      if #ids ~= 0 then
        redis.call('ZADD', KEYS[1], 'XX', unpack(scores_ids(ids, ARGV[3])))
      end

      return ids
      LUA

    getter :client

    def initialize(
      @client : ::Redis::Client,
      @namespace : Symbol | String = :mel
    )
    end

    def self.new(url : String, namespace = :mel)
      new URI.parse(url), namespace
    end

    def self.new(url : URI, namespace = :mel)
      new ::Redis::Client.new(url), namespace
    end

    def key : Key
      Key.new(@namespace)
    end

    def find_due(
      at time = Time.local,
      count : Int = -1, *,
      delete : Bool? = false
    ) : Array(String)?
      return if count.zero?

      if delete.nil?
        ids = @client.eval(
          LUA,
          {key.name},
          {time.to_unix.to_s, count.to_s, worker_score}
        ).as(Array)

        return find(ids, delete: false)
      end

      ids = @client.zrangebyscore(
        key.name,
        "0",
        time.to_unix.to_s,
        {"0", count.to_s}
      ).as(Array)

      find(ids, delete: delete)
    end

    def find_pending(count : Int, *, delete : Bool = false) : Array(String)?
      return if count.zero?

      ids = @client.zrangebyscore(
        key.name,
        worker_score,
        worker_score,
        {"0", count.to_s}
      ).as(Array)

      find(ids, delete: delete)
    end

    def find(count : Int, *, delete : Bool? = false) : Array(String)?
      return if count.zero?

      if delete.nil?
        ids = @client.eval(
          LUA,
          {key.name},
          {"+inf", count.to_s, worker_score}
        ).as(Array)

        return find(ids, delete: false)
      end

      ids = @client.zrangebyscore(
        key.name,
        "0",
        "+inf",
        {"0", count.to_s}
      ).as(Array)

      find(ids, delete: delete)
    end

    def find(ids : Indexable, *, delete : Bool = false) : Array(String)?
      return if ids.empty?

      keys = ids.map { |id| key.name(id.to_s) }

      values = @client.multi do |redis|
        redis.mget(keys)

        if delete
          redis.zrem(key.name, ids.map(&.to_s))
          redis.del(keys)
        end
      end

      values = values.first.as(Array).compact_map(&.as? String)
      values unless values.empty?
    end

    def transaction(& : Transaction -> _)
      @client.multi do |redis|
        yield Transaction.new(redis, key)
      end
    end

    def truncate
      keys = @client.keys("#{key.name}*")
      @client.del(keys.map &.to_s) unless keys.empty?
    end

    def get_progress(ids : Indexable) : Array(String)?
      return if ids.empty?

      keys = ids.map { |id| key.progress(id) }
      values = @client.mget(keys).as(Array).compact_map(&.as? String)

      values unless values.empty?
    end

    def truncate_progress
      keys = @client.keys("#{key.progress}*")
      @client.del(keys.map &.to_s) unless keys.empty?
    end

    private def worker_score
      "-#{Mel.settings.worker_id.abs}"
    end

    struct Transaction
      include Store::Transaction

      def initialize(@client : ::Redis::Transaction, @key : Key)
      end

      def self.new(url : String, namespace = :mel)
        new URI.parse(url), namespace
      end

      def self.new(url : URI, namespace = :mel)
        new ::Redis::Connection.new(url), namespace
      end

      def self.new(connection : Redis::Connection, namespace = :mel)
        new Redis::Transaction.new(connection), namespace
      end

      def create(task : Task)
        @client.zadd(@key.name, {"NX", task.time.to_unix.to_s, task.id})
        @client.set(@key.name(task.id), task.to_json, nx: true)
      end

      def update(task : Task)
        time = task.retry_time || task.time

        @client.zadd(@key.name, time.to_unix.to_s, task.id)
        @client.set(@key.name(task.id), task.to_json)
      end

      def set_progress(id : String, value : Int, description : String)
        report = Progress::Report.new(id, description, value)

        @client.set(
          @key.progress(id),
          report.to_json,
          ex: Mel.settings.progress_expiry
        )
      end
    end

    struct Key
      getter :namespace

      def initialize(@namespace : Symbol | String)
      end

      def name(*parts : Symbol | String) : String
        name_parts(name, parts)
      end

      def name : String
        "#{@namespace}:tasks"
      end

      def progress(*parts : Symbol | String) : String
        name_parts(progress, parts)
      end

      def progress : String
        "#{@namespace}:progress"
      end

      private def name_parts(name, parts)
        "#{name}:#{parts.join(':', &.to_s)}"
      end
    end
  end
end
