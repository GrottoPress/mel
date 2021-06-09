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

    def run
      Mel.redis.multi do |redis|
        yield redis
      end
    end

    def before_run
    end

    def after_run(success)
    end

    def before_enqueue
    end

    def after_enqueue(success)
    end

    def before_dequeue
    end

    def after_dequeue(success)
    end

    {% unless @type < Mel::Instant || @type < Mel::Every || @type < Mel::On %}
    def self.run(id = UUID.random.to_s, retries = 2, redis = nil, **job_args)
      run_now(id, retries, redis, **job_args)
    end

    def self.run_now(
      id = UUID.random.to_s,
      retries = 2,
      redis = nil,
      **job_args
    )
      time = Time.local
      run_at(time, id, retries, redis, **job_args)
    end

    def self.run_in(
      delay : Time::Span,
      id = UUID.random.to_s,
      retries = 2,
      redis = nil,
      **job_args
    )
      time = delay.from_now
      run_at(time, id, retries, redis, **job_args)
    end

    def self.run_at(
      time : Time,
      id = UUID.random.to_s,
      retries = 2,
      redis = nil,
      **job_args
    )
      job = new(**job_args)
      task = Mel::InstantTask.new(id.to_s, job, time, retries)
      task.id if task.enqueue(redis)
    end

    def self.run_every(
      interval : Time::Span,
      for : Time::Span?,
      id = UUID.random.to_s,
      retries = 2,
      redis = nil,
      **job_args
    )
      till = for.try(&.from_now)
      run_every(interval, till, id, retries, redis, **job_args)
    end

    def self.run_every(
      interval : Time::Span,
      till : Time? = nil,
      id = UUID.random.to_s,
      retries = 2,
      redis = nil,
      **job_args
    )
      job = new(**job_args)
      time = interval.abs.from_now
      task = Mel::PeriodicTask.new(id.to_s, job, time, retries, till, interval)

      task.id if task.enqueue(redis)
    end

    def self.run_on(
      schedule : String,
      for : Time::Span?,
      id = UUID.random.to_s,
      retries = 2,
      redis = nil,
      **job_args
    )
      till = for.try(&.from_now)
      run_on(schedule, till, id, retries, redis, **job_args)
    end

    def self.run_on(
      schedule : String,
      till : Time? = nil,
      id = UUID.random.to_s,
      retries = 2,
      redis = nil,
      **job_args
    )
      job = new(**job_args)
      time = CronParser.new(schedule).next
      task = Mel::CronTask.new(id.to_s, job, time, retries, till, schedule)

      task.id if task.enqueue(redis)
    end
    {% end %}
  end
end
