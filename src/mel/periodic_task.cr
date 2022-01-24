require "./recurring_task"

class Mel::PeriodicTask
  include RecurringTask

  @interval : Time::Span

  def initialize(@id, @job, @time, @retries, @till, @interval)
  end

  def interval : Time::Span
    self.interval = @interval
  end

  def interval=(interval)
    @interval = interval.abs
  end

  def to_json : String
    tuple = {
      id: id,
      job: job,
      time: time.to_unix,
      retries: retries,
      attempts: attempts,
      interval: interval.total_seconds.to_i64
    }

    tuple = tuple.merge(till: till.try(&.to_unix)) if till
    tuple.to_json
  end

  def clone
    self.class.new(id, job.dup, time, retries, till, interval)
  end

  private def next_time : Time
    time + interval
  end

  private def log_args
    {
      id: id,
      job: job.class.name,
      time: time.to_unix,
      retries: retries,
      attempts: attempts,
      interval: interval.total_seconds.to_i64,
      till: till.try(&.to_unix)
    }
  end
end
