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

  def add(task, *, force = false)
    force ? update(task) : create(task)
  end

  def create(task)
    connect do
      Mel.redis.multi do |redis|
        redis.run({"ZADD", key, "NX", task.time.to_unix.to_s, task.id})
        redis.set(task.key, task.to_json, nx: true)
      end
    end
  end

  def update(task)
    connect do
      Mel.redis.multi do |redis|
        redis.run({"ZADD", key, task.time.to_unix.to_s, task.id})
        redis.set(task.key, task.to_json)
      end
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
      ids = Mel.redis
        .run({"ZRANGEBYSCORE", key, "-inf", "(#{time.to_unix}"})
        .as(Array)

      find(resize(ids, count), delete: delete)
    end
  end

  def find_lte(time : Time, count = -1, *, delete = false)
    return if count.zero?

    connect do
      ids = Mel.redis
        .run({"ZRANGEBYSCORE", key, "-inf", time.to_unix.to_s})
        .as(Array)

      find(resize(ids, count), delete: delete)
    end
  end

  def find(count : Int32, *, delete = false)
    return if count.zero?

    connect do
      last = count < 1 ? count : count - 1
      ids = Mel.redis.run({"ZRANGE", key, "0", last.to_s}).as(Array)
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
        redis.run(["ZREM", key] + ids) if delete
        redis.run(["DEL"] + keys) if delete
      end

      values[0].as(Array)
    end
  end

  def truncate
    keys = Mel.redis.keys("#{Mel::Task::Query.key}*")

    Mel.redis.multi do |redis|
      redis.del(key)
      redis.run(["DEL"] + keys) unless keys.empty?
    end
  end

  protected def resize(items, count)
    count < 0 ? items : items.first(count)
  end

  private def connect
    yield
  rescue error : IO::Error
    Mel.log.error(exception: error, &.emit("Redis connection failed"))
    nil
  end
end
