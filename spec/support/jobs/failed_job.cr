struct FailedJob
  include Mel::Job

  @[JSON::Field(ignore: true)]
  getter run_before = false

  @[JSON::Field(ignore: true)]
  getter run_after = false

  def run
    raise "Failed on purpose"
  end

  def before_run
    @run_before = true
  end

  def after_run(result)
    @run_after = true
  end
end
