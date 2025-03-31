require "./recurring_task"

module Mel
  class CronTask < RecurringTask
    include Task::LogHelpers
    include Task::CallbackHelpers

    getter schedule : String

    def initialize(id, job, time, retries, @till, @schedule)
      super(id, job, time, retries)
    end

    def to_json(json : JSON::Builder)
      json.object do
        json.field("id", id)
        json.field("job", job)
        json.field("time", time.to_unix)
        json.field("retries", retries.map(&.total_seconds.to_i))
        json.field("attempts", attempts)
        json.field("schedule", schedule)
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
        schedule
      )
    end

    private def next_time : Time
      CronParser.new(schedule).next(time.to_local)
    end

    private def log_args
      {
        id: id,
        job: job.class.name,
        time: time.to_unix,
        retries: retries.map(&.total_seconds.to_i),
        attempts: attempts,
        schedule: schedule,
        till: till.try(&.to_unix)
      }
    end
  end
end
