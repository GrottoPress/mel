module Mel::Job::On
  macro included
    include Mel::Job::Recurring

    def self.run(id = UUID.random.to_s, retries = 2, redis = nil, **job_args)
      job = new(**job_args)

      task = Mel::CronTask.new(
        id.to_s,
        job,
        job.class.time,
        retries,
        job.class.end_time,
        job.class.schedule
      )

      task.id if task.enqueue(redis)
    end
  end

  private macro run_on(schedule, *, till = nil, for = nil)
    run_on({{ till }}, {{ for }}) { {{ schedule }} }
  end

  private macro run_on(till = nil, for = nil)
    def self.schedule : String
      {{ yield }}
    end

    def self.time : Time
      CronParser.new(schedule).next
    end

    def self.end_time : Time?
      {{ till }} || {{ for }}.try(&.from_now)
    end
  end
end
