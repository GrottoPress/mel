class FailedJob
  include Mel::Job

  getter run_before : Bool = false
  getter run_after : Bool = false

  def run
    raise "Failed on purpose"
  end

  def before_run
    @run_before = true
  end

  def after_run(success)
    @run_after = true
  end
end
