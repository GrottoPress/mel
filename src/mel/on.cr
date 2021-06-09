module Mel::On
  macro included
    include Mel::Job

    def self.run(id = UUID.random.to_s, retries = 2, redis = nil, **job_args)
      job = new(**job_args)

      task = Mel::CronTask.new(
        id.to_s,
        job,
        job.time,
        retries,
        job.end_time,
        job.schedule
      )

      task.id if task.enqueue(redis)
    end
  end

  private macro run_on(schedule, *, till = nil, for = nil)
    run_on({{ till }}, {{ for }}) { {{ schedule }} }
  end

  private macro run_on(till = nil, for = nil)
    protected def schedule : String
      {{ yield }}
    end

    protected def time : Time
      CronParser.new(schedule).next
    end

    protected def end_time : Time?
      {{ till }} || {{ for }}.try(&.from_now)
    end
  end
end
