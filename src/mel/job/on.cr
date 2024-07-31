module Mel::Job::On
  macro included
    include Mel::Job::Template

    def self.run_on(
      schedule : String,
      for : Time::Span,
      from : Time = Time.local,
      id = UUID.random.hexstring,
      retries = nil,
      store = nil,
      force = false,
      **job_args
    )
      till = for.from_now
      run_on(schedule, till, from, id, retries, store, force, **job_args)
    end

    def self.run_on(
      schedule : String,
      till : Time? = nil,
      from : Time = Time.local,
      id = UUID.random.hexstring,
      retries = nil,
      store = nil,
      force = false,
      **job_args
    ) : String?
      time = CronParser.new(schedule).next(from)
      job = new(**job_args)
      task = Mel::CronTask.new(id.to_s, job, time, retries, till, schedule)

      task.id if task.enqueue(store, force: force)
    end
  end
end
