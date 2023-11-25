module Mel::Job::At
  macro included
    include Mel::Job::Template

    def self.run_at(
      time : Time,
      id = UUID.random.to_s,
      retries = {1, 2},
      redis = nil,
      force = false,
      **job_args
    ) : String?
      job = new(**job_args)
      task = Mel::InstantTask.new(id.to_s, job, time, retries)
      task.id if task.enqueue(redis, force: force)
    end
  end
end
