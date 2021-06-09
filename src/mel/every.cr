module Mel::Every
  macro included
    include Mel::Job

    def self.run(id = UUID.random.to_s, retries = 2, redis = nil, **job_args)
      job = new(**job_args)

      task = Mel::PeriodicTask.new(
        id.to_s,
        job,
        job.time,
        retries,
        job.end_time,
        job.interval
      )

      task.id if task.enqueue(redis)
    end
  end

  private macro run_every(interval, *, till = nil, for = nil)
    run_every({{ till }}, {{ for }}) { {{ interval }} }
  end

  private macro run_every(till = nil, for = nil)
    protected def interval : Time::Span
      {{ yield }}
    end

    protected def time : Time
      interval.abs.from_now
    end

    protected def end_time : Time?
      {{ till }} || {{ for }}.try(&.from_now)
    end
  end
end
