struct ProgressJob
  include Mel::Job::Now

  def initialize
    @progress = Mel::Progress.new(self.class.progress_id)
  end

  def run
  end

  def after_run(success)
    redis.multi do |redis|
      SomeStep.run(redis: redis, progress: @progress, retries: 0)
      @progress.move(50, redis)
    end
  end

  def self.progress_id
    "progress_job"
  end

  struct SomeStep
    include Mel::Job::Now

    def initialize(@progress : Mel::Progress)
    end

    def run
    end

    def after_run(success)
      redis.multi do |redis|
        SomeOtherStep.run(redis: redis, progress: @progress, retries: 0)
        @progress.forward(30, redis)
      end
    end
  end

  struct SomeOtherStep
    include Mel::Job::Now

    def initialize(@progress : Mel::Progress)
    end

    def run
    end

    def after_run(success)
      @progress.fail
    end
  end
end
