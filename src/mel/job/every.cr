module Mel::Job::Every
  macro included
    include Mel::Job::Recurring

    def self.run(id = UUID.random.to_s, retries = 2, redis = nil, **job_args)
      job = new(**job_args)

      task = Mel::PeriodicTask.new(
        id.to_s,
        job,
        job.class.time,
        retries,
        job.class.end_time,
        job.class.interval
      )

      task.id if task.enqueue(redis)
    end
  end

  private macro run_every(interval, *, till = nil, for = nil)
    run_every({{ till }}, {{ for }}) { {{ interval }} }
  end

  private macro run_every(till = nil, for = nil)
    def self.interval : Time::Span
      {{ yield }}
    end

    def self.time : Time
      interval.abs.from_now
    end

    def self.end_time : Time?
      {{ till }} || {{ for }}.try(&.from_now)
    end
  end
end
