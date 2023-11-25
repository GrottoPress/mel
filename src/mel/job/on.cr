module Mel::Job::On
  macro included
    include Mel::Job::Template

    def self.run_on(
      schedule : String,
      for : Time::Span?,
      id = UUID.random.to_s,
      retries = {1, 2},
      redis = nil,
      force = false,
      **job_args
    )
      till = for.try(&.from_now)
      run_on(schedule, till, id, retries, redis, force, **job_args)
    end

    def self.run_on(
      schedule : String,
      till : Time? = nil,
      id = UUID.random.to_s,
      retries = {1, 2},
      redis = nil,
      force = false,
      **job_args
    ) : String?
      job = new(**job_args)
      time = CronParser.new(schedule).next
      task = Mel::CronTask.new(id.to_s, job, time, retries, till, schedule)
      task.id if task.enqueue(redis, force: force)
    end
  end
end
