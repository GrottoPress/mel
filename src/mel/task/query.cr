module Mel::Task::Query
  extend self

  def key : String
    "mel:tasks"
  end

  def key(*parts : String) : String
    "#{key}:#{parts.join(':')}"
  end

  def keys(ids : Array)
    ids.map { |id| key(id.to_s) }
  end

  def add(task, redis = nil, *, force = false)
    force ? update(task, redis) : create(task, redis)
  end

  def create(task : Task, redis = nil)
    connect do
      command = ->(redis : Redis::Commands) do
        redis.run({"ZADD", key, "NX", task.time.to_unix.to_s, task.id})
        redis.set(task.key, task.to_json, nx: true)
      end

      return command.call(redis) if redis
      Mel.redis.multi { |redis| command.call(redis) }
    end
  end

  def update(task : Task, redis = nil)
    connect do
      command = ->(redis : Redis::Commands) do
        redis.run({"ZADD", key, task.time.to_unix.to_s, task.id})
        redis.set(task.key, task.to_json)
      end

      return command.call(redis) if redis
      Mel.redis.multi { |redis| command.call(redis) }
    end
  end

  def delete(id : String)
    delete([id]).try &.first?.try &.as(String)
  end

  def delete(ids : Array)
    find(ids, delete: true)
  end

  def find_lt(time : Time, count = -1, *, delete = false)
    return if count.zero?

    connect do
      ids = Mel.redis.run({
        "ZRANGEBYSCORE",
        key,
        "0",
        "(#{time.to_unix}",
        "LIMIT",
        "0",
        count.to_s
      }).as(Array)

      find(ids, delete: delete)
    end
  end

  def find_lte(time : Time, count = -1, *, delete = false)
    return if count.zero?

    connect do
      ids = Mel.redis.run({
        "ZRANGEBYSCORE",
        key,
        "0",
        time.to_unix.to_s,
        "LIMIT",
        "0",
        count.to_s
      }).as(Array)

      find(ids, delete: delete)
    end
  end

  def find(count : Int32, *, delete = false)
    return if count.zero?

    connect do
      ids = Mel.redis.run({
        "ZRANGEBYSCORE",
        key,
        "0",
        "+inf",
        "LIMIT",
        "0",
        count.to_s
      }).as(Array)

      find(ids, delete: delete)
    end
  end

  def find_pending(count = -1, *, delete = false)
    return if count.zero?
    delete = false if delete.nil?

    connect do
      ids = Mel.redis.run({
        "ZRANGEBYSCORE",
        key,
        worker_score,
        worker_score,
        "LIMIT",
        "0",
        count.to_s
      }).as(Array)

      find(ids, delete: delete)
    end
  end

  def find(id : String, *, delete = false)
    find([id], delete: delete).try &.first?.try &.as(String)
  end

  def find(ids : Array, *, delete = false)
    return if ids.empty?

    connect do
      keys = keys(ids)

      values = Mel.redis.multi do |redis|
        redis.run(["MGET"] + keys)

        if delete
          redis.run(["ZREM", key] + ids)
          redis.run(["DEL"] + keys)
        elsif delete.nil?
          scores_ids = ids.join(",#{worker_score},").split(',')
          redis.run(["ZADD", key, "XX", worker_score] + scores_ids)
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
      redis.run(["DEL"] + keys) unless keys.empty?
    end
  end

  private def worker_score
    "-#{Mel.settings.worker_id.not_nil!.abs}"
  end

  private def connect
    yield
  rescue error : IO::Error
    Mel.log.error(exception: error, &.emit("Redis connection failed"))
    nil
  end
end
