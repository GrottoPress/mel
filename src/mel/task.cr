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
      job.before_enqueue
      log_enqueueing

      Mel::Task::Query.add(self, force: force).try do |values|
        log_enqueued
        job.after_enqueue
        values
      end
    end

    def dequeue
      job.before_dequeue
      log_dequeueing

      Mel::Task::Query.delete(id).try do |value|
        log_dequeued
        job.after_dequeue
        value
      end
    end

    def run(*, force = false) : Fiber?
      return log_not_due unless force || due?
      job.before_run

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
        job.after_run
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
        tasks = tasks.each.select(&.is_a? self).map(&.as self).to_a
        tasks = Mel::Task::Query.resize(tasks, count)
        next if tasks.empty?

        Mel::Task::Query.delete(tasks.map &.id) if delete
        tasks
      end
    end

    def self.find_lte(time : Time, count = -1, *, delete = false) : Array(self)?
      return if count.zero?

      Mel::Task.find_lte(time, -1, delete: false).try do |tasks|
        tasks = tasks.each.select(&.is_a? self).map(&.as self).to_a
        tasks = Mel::Task::Query.resize(tasks, count)
        next if tasks.empty?

        Mel::Task::Query.delete(tasks.map &.id) if delete
        tasks
      end
    end

    def self.find(count : Int32, *, delete = false) : Array(self)?
      return if count.zero?

      Mel::Task.find(-1, delete: false).try do |tasks|
        tasks = tasks.each.select(&.is_a? self).map(&.as self).to_a
        tasks = Mel::Task::Query.resize(tasks, count)
        next if tasks.empty?

        Mel::Task::Query.delete(tasks.map &.id) if delete
        tasks
      end
    end

    def self.find(id : String, *, delete = false) : self?
      Mel::Task.find(id, delete: false).try do |task|
        next unless task.is_a?(self)
        Mel::Task::Query.delete(task.id) if delete
        task.as(self)
      end
    end

    def self.find(ids : Array, *, delete = false) : Array(self)?
      Mel::Task.find(ids, delete: false).try do |tasks|
        tasks = tasks.each.select(&.is_a? self).map(&.as self).to_a
        next if tasks.empty?

        Mel::Task::Query.delete(tasks.map &.id) if delete
        tasks
      end
    end

    def self.from_json(json) : self?
      Mel::Task.from_json(json).try { |task| task.as(self) if task.is_a?(self) }
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
end
