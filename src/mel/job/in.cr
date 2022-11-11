module Mel::Job::In
  macro included
    include Mel::Job::Template

    def self.run_in(
      delay : Time::Span,
      id = UUID.random.to_s,
      retries = 2,
      redis = nil,
      force = false,
      **job_args
    )
      job = new(**job_args)
      time = delay.from_now
      task = Mel::InstantTask.new(id.to_s, job, time, retries)

      task if task.enqueue(redis, force: force)
    end
  end
end
