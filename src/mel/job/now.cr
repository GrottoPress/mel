module Mel::Job::Now
  macro included
    include Mel::Job::Template

    def self.run(
      id = UUID.random.hexstring,
      retries = nil,
      redis = nil,
      force = false,
      **job_args
    )
      run_now(id, retries, redis, force, **job_args)
    end

    def self.run_now(
      id = UUID.random.hexstring,
      retries = nil,
      redis = nil,
      force = false,
      **job_args
    ) : String?
      job = new(**job_args)
      time = Time.local
      task = Mel::InstantTask.new(id.to_s, job, time, retries)

      task.id if task.enqueue(redis, force: force)
    end
  end
end
