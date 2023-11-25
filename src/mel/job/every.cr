module Mel::Job::Every
  macro included
    include Mel::Job::Template

    def self.run_every(
      interval : Time::Span,
      for : Time::Span?,
      id = UUID.random.to_s,
      retries = {1, 2},
      redis = nil,
      force = false,
      **job_args
    )
      till = for.try(&.from_now)
      run_every(interval, till, id, retries, redis, force, **job_args)
    end

    def self.run_every(
      interval : Time::Span,
      till : Time? = nil,
      id = UUID.random.to_s,
      retries = {1, 2},
      redis = nil,
      force = false,
      **job_args
    ) : String?
      job = new(**job_args)
      time = interval.abs.from_now

      task = Mel::PeriodicTask.new(
        id.to_s,
        job,
        time,
        retries,
        till,
        interval
      )

      task.id if task.enqueue(redis, force: force)
    end
  end
end
