require "./task/**"

abstract class Mel::Task
  def run(*, force = false) : Fiber?
    return log_not_due unless force || due?

    do_before_run
    self.attempts += 1

    spawn(name: id) do
      log_running
      set_run_time
      job.run
    rescue error
      log_errored(error)
      retry_failed_task(error)
    else
      log_ran
      schedule_next
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

  macro inherited
    def self.find_pending(count : Int, *, delete : Bool = false) : Array(self)?
      return if count.zero?

      Mel::Task.find_pending(-1, delete: false).try do |tasks|
        tasks = resize(tasks.select(self), count)
        return if tasks.empty?
        delete(tasks, delete).try &.map(&.as self)
      end
    end
  end

  def self.find_pending(count : Int, *, delete : Bool = false)
    Query.find_pending(count, delete: delete).try { |values| from_json(values) }
  end
end
