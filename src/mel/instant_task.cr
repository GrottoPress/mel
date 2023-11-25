require "./task"

class Mel::InstantTask
  include Task

  def initialize(@id, @job, @time, retries)
    @retries = normalize_retries(retries)
  end

  def to_json(json : JSON::Builder)
    json.object do
      json.field("id", id)
      json.field("job", job)
      json.field("time", time.to_unix)
      json.field("retries", retries.map(&.total_seconds.to_i64))
      json.field("attempts", attempts)
    end
  end

  def clone
    self.class.new(id, job.class.from_json(job.to_json), time, retries)
  end

  private def next_retry_time
    return if attempts > retries.size
    Time.local + retries[attempts - 1]
  end

  private def schedule_next
    dequeue
  end

  private def log_args
    {
      id: id,
      job: job.class.name,
      time: time.to_unix,
      retries: retries.map(&.total_seconds.to_i64),
      attempts: attempts
    }
  end
end
