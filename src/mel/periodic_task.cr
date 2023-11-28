require "./recurring_task"

module Mel
  class PeriodicTask < RecurringTask
    include Task::LogHelpers
    include Task::CallbackHelpers

    @interval : Time::Span

    def initialize(id, job, time, retries, @till, @interval)
      super(id, job, time, retries)
    end

    def interval : Time::Span
      self.interval = @interval
    end

    protected def interval=(interval)
      @interval = interval.abs
    end

    def to_json(json : JSON::Builder)
      json.object do
        json.field("id", id)
        json.field("job", job)
        json.field("time", time.to_unix)
        json.field("retries", retries.map(&.total_seconds.to_i))
        json.field("attempts", attempts)
        json.field("interval", interval.total_seconds.to_i64)
        json.field("till", till.try(&.to_unix))
      end
    end

    def clone : self
      self.class.new(
        id,
        job.class.from_json(job.to_json),
        time,
        retries,
        till,
        interval
      )
    end

    private def log_args
      {
        id: id,
        job: job.class.name,
        time: time.to_unix,
        retries: retries.map(&.total_seconds.to_i),
        attempts: attempts,
        interval: interval.total_seconds.to_i64,
        till: till.try(&.to_unix)
      }
    end
  end
end
