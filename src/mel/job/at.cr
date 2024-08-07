module Mel::Job::At
  macro included
    include Mel::Job::Template

    def self.run_at(
      time : Time,
      id = UUID.random.hexstring,
      retries = nil,
      store = nil,
      force = false,
      **job_args
    ) : String?
      job = new(**job_args)
      task = Mel::InstantTask.new(id.to_s, job, time, retries)

      task.id if task.enqueue(store, force: force)
    end
  end
end
