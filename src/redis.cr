require "redis"

require "./mel"
require "./redis/**"

module Mel
  struct Redis
    include Store

    private LUA = {{ read_file("#{__DIR__}/redis/mel.lua") }}

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
        ids = client.eval(LUA, {key.name}, {
          orphan_timestamp.to_s,
          time.to_unix.to_s,
          count.to_s,
          running_timestamp.to_s,
          run_pool_lua
        }).as(Array)

        RunPool.update(ids)
        return find(ids, delete: false)
      end

      ids = client.zrangebyscore(
        key.name,
        "0",
        time.to_unix.to_s,
        {"0", count.to_s}
      ).as(Array)

      find(ids, delete: delete)
    end

    def find(count : Int, *, delete : Bool? = false) : Array(String)?
      return if count.zero?

      if delete.nil?
        ids = client.eval(LUA, {key.name}, {
          orphan_timestamp.to_s,
          "+inf",
          count.to_s,
          running_timestamp.to_s,
          run_pool_lua
        }).as(Array)

        RunPool.update(ids)
        return find(ids, delete: false)
      end

      ids = client.zrangebyscore(key.name, "0", "+inf", {
        "0",
        count.to_s
      }).as(Array)

      find(ids, delete: delete)
    end

    def find(ids : Indexable, *, delete : Bool = false) : Array(String)?
      return if ids.empty?

      keys = ids.map { |id| key.name(id.to_s) }

      if delete == false
        values = client.mget(keys).as(Array).compact_map(&.as? String)
        return values.empty? ? nil : values
      end

      values = client.multi do |redis|
        redis.mget(keys)
        redis.zrem(key.name, ids.map(&.to_s))
        redis.del(keys)
      end

      values = values.first.as(Array).compact_map(&.as? String)
      values unless values.empty?
    end

    def transaction(& : Transaction -> _)
      client.multi do |redis|
        yield Transaction.new(self, redis)
      end
    end

    def truncate
      keys = client.keys("#{key.name}*")
      client.del(keys.map &.to_s) unless keys.empty?
    end

    def get_progress(ids : Indexable) : Array(String)?
      return if ids.empty?

      keys = ids.map { |id| key.progress(id) }
      values = client.mget(keys).as(Array).compact_map(&.as? String)

      values unless values.empty?
    end

    def truncate_progress
      keys = client.keys("#{key.progress}*")
      client.del(keys.map &.to_s) unless keys.empty?
    end

    private def run_pool_lua
      RunPool.fetch.join(',')
    end

    struct Transaction
      include Mel::Transaction

      def initialize(@redis : Redis, @client : ::Redis::Transaction)
      end

      def self.new(redis : Redis, url : String)
        new redis, URI.parse(url)
      end

      def self.new(redis : Redis, url : URI)
        new redis, ::Redis::Connection.new(url)
      end

      def self.new(redis : Redis, connection : Redis::Connection)
        new redis, ::Redis::Transaction.new(connection)
      end

      def create(task : Task)
        @client.run({
          "ZADD",
          @redis.key.name,
          "NX",
          task.time.to_unix.to_s,
          task.id
        })

        @client.set(@redis.key.name(task.id), task.to_json, nx: true)
      end

      def update(task : Task)
        time = task.retry_time || task.time

        @client.zadd(@redis.key.name, time.to_unix.to_s, task.id)
        @client.set(@redis.key.name(task.id), task.to_json)
      end

      def set_progress(id : String, value : Int, description : String)
        report = Progress::Report.new(id, description, value)

        @client.set(
          @redis.key.progress(id),
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
        "#{namespace}:tasks"
      end

      def progress(*parts : Symbol | String) : String
        name_parts(progress, parts)
      end

      def progress : String
        "#{namespace}:progress"
      end

      private def name_parts(name, parts)
        "#{name}:#{parts.join(':', &.to_s)}"
      end
    end
  end
end
