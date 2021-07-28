struct ProgressJob
  include Mel::Job::Now

  def initialize
    @progress = Mel::Progress.new(self.class.progress_id)
  end

  def run
  end

  def after_run(success)
    return @progress.fail unless success
    SomeStep.run(progress: @progress, retries: 0)
    @progress.track(50)
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
      return @progress.fail unless success
      SomeOtherStep.run(progress: @progress, retries: 0)
      @progress.track(80)
    end
  end

  struct SomeOtherStep
    include Mel::Job::Now

    def initialize(@progress : Mel::Progress)
    end

    def run
      raise "Fail on purpose"
    end

    def after_run(success)
      return @progress.fail unless success
      @progress.succeed
    end
  end
end
