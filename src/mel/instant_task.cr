require "./task"

class Mel::InstantTask
  include Task

  def initialize(@id, @job, @time)
  end

  def to_json : String
    {id: id, job: job, time: time.to_unix, attempts: attempts}.to_json
  end

  def clone
    self.class.new(id, job.dup, time)
  end

  private def reschedule
  end
end
