require "./task/**"

module Mel::Task
  macro included
    include Mel::Task::LogHelpers
    include Mel::Task::CallbackHelpers

    property id : String
    property job : Mel::Job::Template
    property time : Time
    property attempts : Int32 = 0

    @retries : Int32

    def retries : Int32
      self.retries = @retries
    end

    def retries=(retries)
      @retries = retries < 0 ? 0 : retries
    end

    def enqueue(redis = nil, *, force = false)
      do_before_enqueue
      log_enqueueing

      if values = Mel::Task::Query.add(self, redis, force: force)
        log_enqueued
        do_after_enqueue(true)
        values
      else
        do_after_enqueue(false)
        nil
      end
    end

    def dequeue
      do_before_dequeue
      log_dequeueing

      if value = Mel::Task::Query.delete(id)
        log_dequeued
        do_after_dequeue(true)
        value
      else
        do_after_dequeue(false)
        nil
      end
    end

    def run(*, force = false) : Fiber?
      return log_not_due unless force || due?

      do_before_run
      @attempts += 1

      spawn(name: id) do
        log_running
        job.run
      rescue error
        log_errored(error)
        next fail_task(error) if attempts > retries
        schedule_failed_task
      else
        schedule_next
        log_ran
        do_after_run(true)
      end
    end

    def due? : Bool
      time <= Time.local
    end

    def key : String
      Mel::Task::Query.key(id)
    end

    def self.find_lt(time : Time, count = -1, *, delete = false) : Array(self)?
      return if count.zero?

      Mel::Task.find_lt(time, -1, delete: false).try do |tasks|
        tasks = Mel::Task.resize(tasks.select(&.is_a? self), count)
        return if tasks.empty?
        Mel::Task.delete(tasks, delete).try &.map(&.as self)
      end
    end

    def self.find_lte(time : Time, count = -1, *, delete = false) : Array(self)?
      return if count.zero?

      Mel::Task.find_lte(time, -1, delete: false).try do |tasks|
        tasks = Mel::Task.resize(tasks.select(&.is_a? self), count)
        return if tasks.empty?
        Mel::Task.delete(tasks, delete).try &.map(&.as self)
      end
    end

    def self.find(count : Int32, *, delete = false) : Array(self)?
      return if count.zero?

      Mel::Task.find(-1, delete: false).try do |tasks|
        tasks = Mel::Task.resize(tasks.select(&.is_a? self), count)
        return if tasks.empty?
        Mel::Task.delete(tasks, delete).try &.map(&.as self)
      end
    end

    def self.find(id : String, *, delete = false) : self?
      Mel::Task.find(id, delete: false).try do |task|
        return unless task.is_a?(self)
        Mel::Task.delete(task, delete).try &.as(self)
      end
    end

    def self.find(ids : Array, *, delete = false) : Array(self)?
      Mel::Task.find(ids, delete: false).try do |tasks|
        tasks = tasks.select(&.is_a? self)
        return if tasks.empty?
        Mel::Task.delete(tasks, delete).try &.map(&.as self)
      end
    end

    def self.from_json(values) : Array(self)?
      Mel::Task.from_json(values).try do |tasks|
        tasks = tasks.each.select(&.is_a? self).map(&.as self).to_a
        tasks unless tasks.empty?
      end
    end

    def self.from_json(value) : self?
      Mel::Task.from_json(value).try do |task|
        task.as(self) if task.is_a?(self)
      end
    end

    private def fail_task(error) : Nil
      schedule_next
      log_failed

      do_after_run(false)
      raise_or(error)
    end

    private def schedule_failed_task : Nil
      original = clone
      original.attempts = attempts
      original.enqueue(force: true)
    end
  end

  extend self

  def find_lt(time : Time, count = -1, *, delete = false)
    Query.find_lt(time, count, delete: delete).try do |values|
      from_json(values)
    end
  end

  def find_lte(time : Time, count = -1, *, delete = false)
    Query.find_lte(time, count, delete: delete).try do |values|
      from_json(values)
    end
  end

  def find(count : Int32, *, delete = false)
    Query.find(count, delete: delete).try { |values| from_json(values) }
  end

  def find(id : String, *, delete = false) : self?
    Query.find(id, delete: delete).try { |value| from_json(value) }
  end

  def find(ids : Array, *, delete = false)
    Query.find(ids, delete: delete).try { |values| from_json(values) }
  end

  def from_json(values : Array)
    values = values.each
      .map { |value| from_json(value.to_s) if value }
      .reject(&.nil?)
      .map(&.not_nil!)
      .to_a

    values unless values.empty?
  end

  def from_json(value) : self?
    json = JSON.parse(value)

    job_type = {{ Job::Template.includers }}.find do |type|
      type.name == json["job"]["__type__"].as_s
    end

    job_type.try { |type| from_json(json, type) }
  end

  private def from_json(json, type)
    id = json["id"].as_s
    job = type.from_json(json["job"].to_json)
    time = Time.unix(json["time"].as_i64)
    retries = json["retries"].as_i
    attempts = json["attempts"].as_i
    till = json["till"]?.try { |timestamp| Time.unix(timestamp.as_i64) }
    schedule = json["schedule"]?.try(&.as_s)
    interval = json["interval"]?.try(&.as_i64.seconds)

    if schedule
      task = CronTask.new(id, job, time, retries, till, schedule)
    elsif interval
      task = PeriodicTask.new(id, job, time, retries, till, interval)
    else
      task = InstantTask.new(id, job, time, retries)
    end

    task.attempts = attempts
    task
  end

  protected def resize(items, count)
    count < 0 ? items : items.first(count)
  end

  protected def delete(tasks : Array, delete)
    delete == false ? tasks : Mel::Task.find(tasks.map(&.id), delete: delete)
  end

  protected def delete(task, delete)
    delete == false ? task : Mel::Task.find(task.id, delete: delete)
  end
end
