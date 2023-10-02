struct FailCallbacksJob
  include Mel::Job

  @[JSON::Field(ignore: true)]
  getter done = false

  def run
    @done = true
  end

  def before_run
    raise "Fail on purpose"
  end

  def after_run(success)
    raise "Fail on purpose"
  end

  def before_enqueue
    raise "Fail on purpose"
  end

  def after_enqueue(success)
    raise "Fail on purpose"
  end

  def before_dequeue
    raise "Fail on purpose"
  end

  def after_dequeue(success)
    raise "Fail on purpose"
  end
end
