module Mel::Job::Every
  macro included
    include Mel::Job::Template

    def self.run_every(
      interval : Time::Span,
      for : Time::Span,
      from : Time? = nil,
      id = UUID.random.hexstring,
      retries = nil,
      redis = nil,
      force = false,
      **job_args
    )
      till = for.from_now
      run_every(interval, till, from, id, retries, redis, force, **job_args)
    end

    def self.run_every(
      interval : Time::Span,
      till : Time? = nil,
      from : Time? = nil,
      id = UUID.random.hexstring,
      retries = nil,
      redis = nil,
      force = false,
      **job_args
    ) : String?
      time = from || interval.abs.from_now
      job = new(**job_args)

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
