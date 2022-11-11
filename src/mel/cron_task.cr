require "./recurring_task"

class Mel::CronTask
  include RecurringTask

  property schedule : String

  def initialize(@id, @job, @time, @retries, @till, @schedule)
  end

  def to_json : String
    JSON.build { |json| to_json(json) }
  end

  def to_json(json)
    json.object do
      json.field("id", id)
      json.field("job", job)
      json.field("time", time.to_unix)
      json.field("retries", retries)
      json.field("attempts", attempts)
      json.field("schedule", schedule)
      json.field("till", till.try(&.to_unix)) if till
    end
  end

  def clone
    self.class.new(id, job.dup, time, retries, till, schedule)
  end

  private def next_time : Time
    CronParser.new(schedule).next(time.to_local)
  end

  private def log_args
    {
      id: id,
      job: job.class.name,
      time: time.to_unix,
      retries: retries,
      attempts: attempts,
      schedule: schedule,
      till: till.try(&.to_unix)
    }
  end
end
