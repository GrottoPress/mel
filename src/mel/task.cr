require "./task/**"

module Mel::Task
  macro included
    include Mel::Task::LogHelpers

    property id : String
    property job : Job
    property time : Time
    property attempts : Int32 = 0

    private MAX_ATTEMPTS = 3

    def enqueue(*, force = false)
      connect do
        log_enqueueing

        value = Mel.redis.multi do |redis|
          if force
            redis.run({"ZADD", Task.key, time.to_unix.to_s, id})
            redis.set(key, to_json)
          else
            redis.run({"ZADD", Task.key, "NX", time.to_unix.to_s, id})
            redis.set(key, to_json, nx: true)
          end
        end

        log_enqueued(result = value.none?(0))
        result
      end
    end

    def dequeue
      connect do
        log_dequeueing

        value = Mel.redis.multi do |redis|
          redis.run({"ZREM", Task.key, id})
          redis.del(key)
        end

        log_dequeued(result = value.none?(0))
        result
      end
    end

    def run(*, force = false) : Fiber?
      return log_not_due unless force || due?

      original = clone
      reschedule
      @attempts += 1

      spawn(name: id) do
        log_running
        job.run
      rescue error
        log_errored(error)
        next log_failed if attempts >= MAX_ATTEMPTS
        original.attempts = attempts
        original.enqueue(force: true)
      else
        log_ran
      end
    end

    def due? : Bool
      time <= Time.local
    end

    def key : String
      Task.key(id)
    end

    def self.find(count : Int32, *, delete = false) : Array(self)?
      Task.find(count, delete: delete).try &.each
        .select(&.is_a? self)
        .map(&.as self)
        .to_a
    end

    def self.find(id : String, *, delete = false) : self?
      Task.find(id, delete: delete).try(&.as self)
    rescue TypeCastError
    end

    def self.find(ids : Array, *, delete = false) : Array(self)?
      Task.find(ids, delete: delete).try &.each
        .select(&.is_a? self)
        .map(&.as self)
        .to_a
    end

    def self.find_lt(time : Time, count = -1, *, delete = false) : Array(self)?
      Task.find_lt(time, count, delete: delete).try &.each
        .select(&.is_a? self)
        .map(&.as self)
        .to_a
    end

    def self.find_lte(time : Time, count = -1, *, delete = false) : Array(self)?
      Task.find_lte(time, count, delete: delete).try &.each
        .select(&.is_a? self)
        .map(&.as self)
        .to_a
    end

    def self.from_json(json) : self?
      Task.from_json(json).try(&.as self)
    rescue TypeCastError
    end
  end

  extend self

  def key : String
    "mel:tasks"
  end

  def key(*parts : String) : String
    "#{key}:#{parts.join(':')}"
  end

  def find(count : Int32, *, delete = false)
    return if count.zero?

    connect do
      last = count < 1 ? count : count - 1
      ids = Mel.redis.run({"ZRANGE", key, "0", last.to_s}).as(Array)
      find(ids, delete: delete)
    end
  end

  def find(id : String, *, delete = false) : self?
    find([id], delete: delete).try &.first?
  end

  def find(ids : Array, *, delete = false)
    return if ids.empty?
    keys = ids.map { |id| key(id.to_s) }

    connect do
      values = Mel.redis.multi do |redis|
        redis.run(["MGET"] + keys)
        redis.run(["ZREM", Task.key] + keys) if delete
        redis.run(["DEL"] + keys) if delete
      end

      return unless values = values.first?

      values = values.as(Array)
      values = values.each.map { |value| from_json(value.to_s) if value }
      values.reject(&.nil?).map(&.not_nil!).to_a
    end
  end

  def find_lt(time : Time, count = -1, *, delete = false)
    return if count.zero?

    connect do
      ids = Mel.redis
        .run({"ZRANGEBYSCORE", key, "-inf", "(#{time.to_unix}"})
        .as(Array)

      find(ids(ids, count), delete: delete)
    end
  end

  def find_lte(time : Time, count = -1, *, delete = false)
    return if count.zero?

    connect do
      ids = Mel.redis
        .run({"ZRANGEBYSCORE", key, "-inf", time.to_unix.to_s})
        .as(Array)

      find(ids(ids, count), delete: delete)
    end
  end

  def from_json(json) : self?
    json = JSON.parse(json)

    job_type = {{ Job.includers }}.find do |type|
      type.name == json["job"]["__type__"].as_s
    end

    return unless type = job_type

    id = json["id"].as_s
    job = type.from_json(json["job"].to_json)
    time = Time.unix(json["time"].as_i64)
    till = json["till"]?.try { |t| Time.unix(t.as_i64) }
    attempts = json["attempts"].as_i

    if schedule = json["schedule"]?
      task = CronTask.new(id, job, time, till, schedule.as_s)
    elsif interval = json["interval"]?
      task = PeriodicTask.new(id, job, time, till, interval.as_i64.seconds)
    else
      task = InstantTask.new(id, job, time)
    end

    task.attempts = attempts
    task
  end

  private def ids(ids, count)
    count < 0 ? ids : ids.first(count)
  end

  private def connect
    yield
  rescue error : IO::Error
    Mel.log.error(exception: error, &.emit("Redis connection failed"))
    nil
  end
end
