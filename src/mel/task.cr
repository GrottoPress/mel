require "./task/**"

abstract class Mel::Task
  getter id : String
  getter job : Job::Template
  getter time : Time
  getter retries : Array(Time::Span)
  getter attempts : Int32 = 0

  protected setter time : Time
  protected setter attempts : Int32
  protected property retry_time : Time?

  abstract def clone : self
  abstract def to_json(json : JSON::Builder)

  def initialize(@id, @job, @time, retries)
    @retries = normalize_retries(retries)
  end

  def enqueue(store = nil, *, force = false)
    do_before_enqueue
    log_enqueueing

    Mel.settings.store.try &.add(self, store, force: force).tap do
      log_enqueued
      do_after_enqueue(true)
    end
  rescue error
    handle_error(error)
    do_after_enqueue(false)
  end

  def dequeue
    do_before_dequeue
    log_dequeueing

    Mel.settings.store.try &.delete(id).tap do
      log_dequeued
      do_after_dequeue(true)
    end
  rescue error
    handle_error(error)
    do_after_dequeue(false)
  end

  def run(pond : Pond, *, force = false) : Fiber?
    return log_not_due unless force || due?
    do_before_run

    self.attempts += 1
    set_run_time

    pond.fill(name: id) do
      log_running
      job.run
    rescue error
      log_errored(error)
      retry_failed_task(error)
    else
      log_ran
      schedule_next
      do_after_run(true)
    ensure
      RunQueue.delete(id)
    end
  end

  def due?(at time = Time.local) : Bool
    self.time <= time
  end

  private def retry_failed_task(error) : Nil
    return if attempts < 1

    next_time = next_retry_time
    return fail_task(error) unless next_time

    new_task = clone
    new_task.attempts = attempts
    new_task.retry_time = next_time
    new_task.enqueue(force: true)
  end

  private def next_retry_time
    return if attempts > retries.size
    Time.local + retries[attempts - 1]
  end

  private def fail_task(error) : Nil
    log_failed
    schedule_next

    handle_error(error)
    do_after_run(false)
  end

  private def set_run_time
    self.time = Time.local if first_attempt?
  end

  private def first_attempt?
    1 == attempts
  end

  private def normalize_retries(retries)
    case retries
    in Int
      retries > 0 ? Array.new(retries, 0.seconds) : Array(Time::Span).new
    in Indexable
      retries.map { |time| time.is_a?(Time::Span) ? time : time.seconds }.to_a
    in Nil
      [2.seconds, 4.seconds, 8.seconds, 16.seconds]
    end
  end

  macro inherited
    def self.find_due(
      at time = Time.local,
      count : Int = -1, *,
      delete : Bool = false
    ) : Array(self)?
      return if count.zero?

      Mel::Task.find_due(time, -1, delete: false).try do |tasks|
        tasks = resize(tasks.select(self), count)
        return if tasks.empty?
        delete(tasks, delete).try &.map(&.as self)
      end
    end

    def self.find(count : Int, *, delete : Bool = false) : Array(self)?
      return if count.zero?

      Mel::Task.find(-1, delete: false).try do |tasks|
        tasks = resize(tasks.select(self), count)
        return if tasks.empty?
        delete(tasks, delete).try &.map(&.as self)
      end
    end

    def self.find(id : String, *, delete : Bool = false) : self?
      Mel::Task.find(id, delete: false).try do |task|
        return unless task.is_a?(self)
        delete(task, delete).try &.as(self)
      end
    end

    def self.find(ids : Indexable, *, delete : Bool = false) : Array(self)?
      Mel::Task.find(ids, delete: false).try do |tasks|
        tasks = tasks.select(self)
        return if tasks.empty?
        delete(tasks, delete).try &.map(&.as self)
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

    private def self.resize(items, count)
      count < 0 ? items : items.first(count)
    end

    private def self.delete(tasks : Indexable, delete)
      false == delete ? tasks : Mel::Task.find(tasks.map(&.id), delete: delete)
    end

    private def self.delete(task, delete)
      false == delete ? task : Mel::Task.find(task.id, delete: delete)
    end
  end

  def self.find_due(
    at time = Time.local,
    count : Int = -1, *,
    delete : Bool? = false
  )
    Mel.settings.store.try do |store|
      store.find_due(time, count, delete: delete).try do |values|
        from_json(values)
      end
    end
  end

  def self.find(count : Int, *, delete : Bool? = false)
    Mel.settings.store.try &.find(count, delete: delete).try do |values|
      from_json(values)
    end
  end

  def self.find(id : String, *, delete : Bool = false)
    Mel.settings.store.try &.find(id, delete: delete).try do |value|
      from_json(value)
    end
  end

  def self.find(ids : Indexable, *, delete : Bool = false)
    Mel.settings.store.try &.find(ids, delete: delete).try do |values|
      from_json(values)
    end
  end

  def self.from_json(values : Indexable)
    values = values.compact_map { |value| from_json(value.to_s) if value }
    values unless values.empty?
  end

  def self.from_json(value)
    json = JSON.parse(value)

    job_type = {{ Job::Template.includers }}.find do |type|
      type.name == json["job"]["__type__"].as_s
    end

    job_type.try { |type| from_json(json, type) }
  end

  private def self.from_json(json, job_type)
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
end
