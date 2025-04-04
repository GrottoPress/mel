struct ProgressJob
  include Mel::Job::Now

  def initialize
    @progress = Mel::Progress.start(
      self.class.progress_id,
      self.class.progress_description
    )
  end

  def run
  end

  def after_run(success)
    Mel.transaction do |store|
      SomeStep.run(store: store, progress: @progress, retries: 0)
      @progress.move(50, store)
    end
  end

  def self.progress_id
    "progress_job"
  end

  def self.progress_description
    "Progress job"
  end

  struct SomeStep
    include Mel::Job::Now

    def initialize(@progress : Mel::Progress)
    end

    def run
    end

    def after_run(success)
      Mel.transaction do |store|
        SomeOtherStep.run(store: store, progress: @progress, retries: 0)
        @progress.move(80, store)
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
