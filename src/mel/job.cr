module Mel::Job
  macro included
    include JSON::Serializable

    # Fixes compile error:
    #
    # "Error: wrong number of arguments for 'CollectJobsJob.new'
    # (given 0, expected 1)"
    macro finished
      \{% if !@type.methods.map(&.name).includes?(:initialize.id) %}
        def initialize
        end
      \{% end %}
    end

    @__type__ : String = name

    def run
      \{% raise "#{@type}#run not implemented" %}
    end

    def self.run(id = UUID.random.to_s, **job_args)
      run_now(id, **job_args)
    end

    def self.run_now(id = UUID.random.to_s, **job_args)
      time = Time.local
      run_at(time, id, **job_args)
    end

    def self.run_in(delay : Time::Span, id = UUID.random.to_s, **job_args)
      time = delay.from_now
      run_at(time, id, **job_args)
    end

    def self.run_at(time : Time, id = UUID.random.to_s, **job_args)
      job = new(**job_args)
      task = Mel::InstantTask.new(id.to_s, job, time)
      task if task.enqueue
    end

    def self.run_every(
      interval : Time::Span,
      for : Time::Span?,
      id = UUID.random.to_s,
      **job_args
    )
      till = for.try(&.from_now)
      run_every(interval, till, id, **job_args)
    end

    def self.run_every(
      interval : Time::Span,
      till : Time? = nil,
      id = UUID.random.to_s,
      **job_args
    )
      job = new(**job_args)
      time = interval.from_now
      task = Mel::PeriodicTask.new(id.to_s, job, time, till, interval)

      task if task.enqueue
    end

    def self.run_on(
      schedule : String,
      for : Time::Span?,
      id = UUID.random.to_s,
      **job_args
    )
      till = for.try(&.from_now)
      run_on(schedule, till, id, **job_args)
    end

    def self.run_on(
      schedule : String,
      till : Time? = nil,
      id = UUID.random.to_s,
      **job_args
    )
      job = new(**job_args)
      time = CronParser.new(schedule).next
      task = Mel::CronTask.new(id.to_s, job, time, till, schedule)

      task if task.enqueue
    end
  end
end
