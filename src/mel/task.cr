require "./task/**"

module Mel::Task
  macro included
    include Mel::Task::LogHelpers
    include Mel::Task::CallbackHelpers

    getter id : String
    getter job : Mel::Job::Template
    getter time : Time
    getter retries : Array(Time::Span)
    getter attempts : Int32 = 0

    protected setter time : Time
    protected setter attempts : Int32

    protected property retry_time : Time?

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
    rescue error
      do_after_enqueue(false)
      handle_error(error)
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
    rescue error
      do_after_enqueue(false)
      handle_error(error)
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
        retry_failed_task(error)
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
        tasks = Mel::Task.resize(tasks.select(self), count)
        return if tasks.empty?
        Mel::Task.delete(tasks, delete).try &.map(&.as self)
      end
    end

    def self.find_lte(time : Time, count = -1, *, delete = false) : Array(self)?
      return if count.zero?

      Mel::Task.find_lte(time, -1, delete: false).try do |tasks|
        tasks = Mel::Task.resize(tasks.select(self), count)
        return if tasks.empty?
        Mel::Task.delete(tasks, delete).try &.map(&.as self)
      end
    end

    def self.find(count : Int32, *, delete = false) : Array(self)?
      return if count.zero?

      Mel::Task.find(-1, delete: false).try do |tasks|
        tasks = Mel::Task.resize(tasks.select(self), count)
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

    def self.find(ids : Indexable, *, delete = false) : Array(self)?
      Mel::Task.find(ids, delete: false).try do |tasks|
        tasks = tasks.select(self)
        return if tasks.empty?
        Mel::Task.delete(tasks, delete).try &.map(&.as self)
      end
    end

    def self.from_json(values : Indexable) : Array(self)?
      Mel::Task.from_json(values).try do |tasks|
        tasks = tasks.each.select(self).map(&.as self).to_a
        tasks unless tasks.empty?
      end
    end

    def self.from_json(value) : self?
      Mel::Task.from_json(value).try do |task|
        task.as(self) if task.is_a?(self)
      end
    end

    private def retry_failed_task(error) : Nil
      return if attempts < 1

      next_retry_time.try do |time|
        original = clone
        original.attempts = attempts
        original.retry_time = time
        original.enqueue(force: true)
      end || fail_task(error)
    end

    private def fail_task(error) : Nil
      schedule_next
      log_failed

      handle_error(error)
      do_after_run(false)
    end

    private def normalize_retries(retries)
      case retries
      in Int
        retries > 0 ? Array.new(retries, 0.seconds) : Array(Time::Span).new
      in Indexable
        retries.map { |time| time.is_a?(Time::Span) ? time : time.seconds }.to_a
      in Nil
        [1.second, 2.seconds]
      end
    end
  end

  alias Any = CronTask | InstantTask | PeriodicTask

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

  def find(id : String, *, delete = false)
    Query.find(id, delete: delete).try { |value| from_json(value) }
  end

  def find(ids : Indexable, *, delete = false)
    Query.find(ids, delete: delete).try { |values| from_json(values) }
  end

  def from_json(values : Indexable)
    values = values.compact_map { |value| from_json(value.to_s) if value }
    values unless values.empty?
  end

  def from_json(value)
    json = JSON.parse(value)

    job_type = {{ Job::Template.includers }}.find do |type|
      type.name == json["job"]["__type__"].as_s
    end

    job_type.try { |type| from_json(json, type) }
  end

  private def from_json(json, job_type)
    id = json["id"].as_s
    job = job_type.from_json(json["job"].to_json)
    time = Time.unix(json["time"].as_i64)
    retries = json["retries"].as_a?.try &.map(&.as_i64.seconds)
    attempts = json["attempts"].as_i
    till = json["till"]?.try &.as_i64?.try { |timestamp| Time.unix(timestamp) }
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

  protected def delete(tasks : Indexable, delete)
    delete == false ? tasks : Mel::Task.find(tasks.map(&.id), delete: delete)
  end

  protected def delete(task, delete)
    delete == false ? task : Mel::Task.find(task.id, delete: delete)
  end
end
