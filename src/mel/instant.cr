module Mel::Instant
  macro included
    include Mel::Job

    protected def time : Time
    end

    def self.run(id = UUID.random.to_s, retries = 2, redis = nil, **job_args)
      job = new(**job_args)
      task = Mel::InstantTask.new(id.to_s, job, job.time, retries)
      task.id if task.enqueue(redis)
    end
  end
end
