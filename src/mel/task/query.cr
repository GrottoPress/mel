module Mel::Task::Query
  extend self

  include Mel::Helpers

  def key : String
    "#{Mel.settings.redis_key_prefix}:tasks"
  end

  def key(*parts : String) : String
    "#{key}:#{parts.join(':')}"
  end

  def keys(ids : Indexable)
    ids.map { |id| key(id.to_s) }
  end

  def add(task, redis = nil, *, force = false)
    force ? update(task, redis) : create(task, redis)
  end

  def create(task : Task, redis = nil)
    connect do
      command = ->(_redis : Redis::Commands) do
        _redis.zadd(key, {"NX", task.time.to_unix.to_s, task.id})
        _redis.set(task.key, task.to_json, nx: true)
      end

      return command.call(redis) if redis
      Mel.redis.multi { |_redis| command.call(_redis) }
    end
  end

  def update(task : Task, redis = nil)
    connect do
      command = ->(_redis : Redis::Commands) do
        _redis.zadd(key, task.time.to_unix.to_s, task.id)
        _redis.set(task.key, task.to_json)
      end

      return command.call(redis) if redis
      Mel.redis.multi { |_redis| command.call(_redis) }
    end
  end

  def delete(id : String)
    delete({id}).try &.first?.try &.as(String)
  end

  def delete(ids : Indexable)
    find(ids, delete: true)
  end

  def find_lt(time : Time, count = -1, *, delete = false)
    return if count.zero?

    connect do
      ids = Mel.redis.zrangebyscore(
        key,
        "0",
        "(#{time.to_unix}",
        {"0", count.to_s}
      ).as(Array)

      find(ids, delete: delete)
    end
  end

  def find_lte(time : Time, count = -1, *, delete = false)
    return if count.zero?

    connect do
      ids = Mel.redis.zrangebyscore(
        key,
        "0",
        time.to_unix.to_s,
        {"0", count.to_s}
      ).as(Array)

      find(ids, delete: delete)
    end
  end

  def find(count : Int32, *, delete = false)
    return if count.zero?

    connect do
      ids = Mel.redis.zrangebyscore(
        key,
        "0",
        "+inf",
        {"0", count.to_s}
      ).as(Array)

      find(ids, delete: delete)
    end
  end

  def find(id : String, *, delete = false)
    find({id}, delete: delete).try &.first?.try &.as(String)
  end

  def find(ids : Indexable, *, delete = false)
    return if ids.empty?

    connect do
      keys = keys(ids)

      values = Mel.redis.multi do |redis|
        redis.mget(keys)

        if delete
          redis.run(["ZREM", key] + ids.to_a)
          redis.del(keys)
        end
      end

      values = values[0].as(Array)
      values unless values.empty?
    end
  end

  def truncate
    keys = Mel.redis.keys("#{key}*")

    Mel.redis.multi do |redis|
      redis.del(key)
      redis.del(keys.map &.to_s) unless keys.empty?
    end
  end

  private def connect
    yield
  rescue error : IO::Error
    Mel.log.error(exception: error, &.emit("Redis connection failed"))
    raise error
  end
end
