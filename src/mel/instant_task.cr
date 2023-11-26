require "./task"

module Mel
  class InstantTask < Task
    include Task::LogHelpers
    include Task::CallbackHelpers

    def to_json(json : JSON::Builder)
      json.object do
        json.field("id", id)
        json.field("job", job)
        json.field("time", time.to_unix)
        json.field("retries", retries.map(&.total_seconds.to_i))
        json.field("attempts", attempts)
      end
    end

    def clone : self
      self.class.new(id, job.class.from_json(job.to_json), time, retries)
    end

    private def schedule_next
      dequeue
    end

    private def log_args
      {
        id: id,
        job: job.class.name,
        time: time.to_unix,
        retries: retries.map(&.total_seconds.to_i),
        attempts: attempts
      }
    end
  end
end
