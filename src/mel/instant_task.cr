require "./task"

class Mel::InstantTask
  include Task

  def initialize(@id, @job, @time, @retries)
  end

  def to_json : String
    {
      id: id,
      job: job,
      time: time.to_unix,
      retries: retries,
      attempts: attempts
    }.to_json
  end

  def clone
    self.class.new(id, job.dup, time, retries)
  end

  private def schedule_next
    dequeue
  end
end
