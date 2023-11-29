require "./task/**"

abstract class Mel::Task
  def dequeue_pending
    do_before_dequeue
    log_dequeueing

    Query.delete_pending(id).tap do
      log_dequeued
      do_after_dequeue(true)
    end
  rescue error
    handle_error(error)
    do_after_dequeue(false)
  end

  def run(*, force = false) : Fiber?
    return log_not_due unless force || due?

    do_before_run
    @attempts += 1

    spawn(name: id) do
      log_running
      job.run
    rescue error
      dequeue_pending
      retry_failed_task(error)
      log_errored(error)
    else
      dequeue_pending
      schedule_next
      log_ran
      do_after_run(true)
    end
  end

  def due? : Bool
    time <= Time.local
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

  private def next_retry_time
    return if attempts > retries.size
    Time.local + retries[attempts - 1]
  end

  private def fail_task(error) : Nil
    schedule_next
    log_failed

    handle_error(error)
    do_after_run(false)
  end

  macro inherited
    def self.find_pending(count : Int, *, delete = false) : Array(self)?
      return if count.zero?

      Mel::Task.find_pending(-1, delete: false).try do |tasks|
        tasks = resize(tasks.select(self), count)
        return if tasks.empty?
        delete_pending(tasks, delete).try &.map(&.as self)
      end
    end

    def self.find_pending(id : String, *, delete = false) : self?
      Mel::Task.find_pending(id, delete: false).try do |task|
        return unless task.is_a?(self)
        delete_pending(task, delete).try &.as(self)
      end
    end

    def self.find_pending(ids : Indexable, *, delete = false) : Array(self)?
      Mel::Task.find_pending(ids, delete: false).try do |tasks|
        tasks = tasks.select(self)
        return if tasks.empty?
        delete_pending(tasks, delete).try &.map(&.as self)
      end
    end

    private def self.delete_pending(tasks : Indexable, delete)
      false == delete ?
        tasks :
        Mel::Task.find_pending(tasks.map(&.id), delete: delete)
    end

    private def self.delete_pending(task, delete)
      false == delete ? task : Mel::Task.find_pending(task.id, delete: delete)
    end
  end

  def self.find_pending(count : Int, *, delete = false)
    Query.find_pending(count, delete: delete).try { |values| from_json(values) }
  end

  def self.find_pending(id : String, *, delete = false)
    Query.find_pending(id, delete: delete).try { |value| from_json(value) }
  end

  def self.find_pending(ids : Indexable, *, delete = false)
    Query.find_pending(ids, delete: delete).try { |values| from_json(values) }
  end
end
