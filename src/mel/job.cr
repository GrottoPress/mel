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

    {% if @type < Mel::Job::Now || !(@type < Mel::Job::Template) %}
      def self.run(
        id = UUID.random.to_s,
        retries = 2,
        redis = nil,
        force = false,
        **job_args
      )
        run_now(id, retries, redis, force, **job_args)
      end

      def self.run_now(
        id = UUID.random.to_s,
        retries = 2,
        redis = nil,
        force = false,
        **job_args
      )
        job = new(**job_args)
        time = Time.local
        task = Mel::InstantTask.new(id.to_s, job, time, retries)

        task.id if task.enqueue(redis, force: force)
      end
    {% end %}

    {% if @type < Mel::Job::In || !(@type < Mel::Job::Template) %}
      def self.run_in(
        delay : Time::Span,
        id = UUID.random.to_s,
        retries = 2,
        redis = nil,
        force = false,
        **job_args
      )
        job = new(**job_args)
        time = delay.from_now
        task = Mel::InstantTask.new(id.to_s, job, time, retries)

        task.id if task.enqueue(redis, force: force)
      end
    {% end %}

    {% if @type < Mel::Job::At || !(@type < Mel::Job::Template) %}
      def self.run_at(
        time : Time,
        id = UUID.random.to_s,
        retries = 2,
        redis = nil,
        force = false,
        **job_args
      )
        job = new(**job_args)
        task = Mel::InstantTask.new(id.to_s, job, time, retries)
        task.id if task.enqueue(redis, force: force)
      end
    {% end %}

    {% if @type < Mel::Job::Every || !(@type < Mel::Job::Template) %}
      def self.run_every(
        interval : Time::Span,
        for : Time::Span?,
        id = UUID.random.to_s,
        retries = 2,
        redis = nil,
        force = false,
        **job_args
      )
        till = for.try(&.from_now)
        run_every(interval, till, id, retries, redis, force, **job_args)
      end

      def self.run_every(
        interval : Time::Span,
        till : Time? = nil,
        id = UUID.random.to_s,
        retries = 2,
        redis = nil,
        force = false,
        **job_args
      )
        job = new(**job_args)
        time = interval.abs.from_now

        task = Mel::PeriodicTask.new(
          id.to_s,
          job,
          time,
          retries,
          till,
          interval
        )

        task.id if task.enqueue(redis, force: force)
      end
    {% end %}

    {% if @type < Mel::Job::On || !(@type < Mel::Job::Template) %}
      def self.run_on(
        schedule : String,
        for : Time::Span?,
        id = UUID.random.to_s,
        retries = 2,
        redis = nil,
        force = false,
        **job_args
      )
        till = for.try(&.from_now)
        run_on(schedule, till, id, retries, redis, force, **job_args)
      end

      def self.run_on(
        schedule : String,
        till : Time? = nil,
        id = UUID.random.to_s,
        retries = 2,
        redis = nil,
        force = false,
        **job_args
      )
        job = new(**job_args)
        time = CronParser.new(schedule).next
        task = Mel::CronTask.new(id.to_s, job, time, retries, till, schedule)

        task.id if task.enqueue(redis, force: force)
      end
    {% end %}

    private def redis
      Mel.redis
    end
  end
end
