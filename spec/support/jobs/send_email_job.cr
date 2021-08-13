struct SendEmailJob
  include Mel::Job

  getter :address

  @[JSON::Field(ignore: true)]
  getter sent = false

  @[JSON::Field(ignore: true)]
  getter run_before = false

  @[JSON::Field(ignore: true)]
  getter run_after = false

  getter enqueue_before = false

  @[JSON::Field(ignore: true)]
  getter enqueue_after = false

  @[JSON::Field(ignore: true)]
  getter dequeue_before = false

  @[JSON::Field(ignore: true)]
  getter dequeue_after = false

  def initialize(@address : String)
  end

  def run
    @sent = true
  end

  def before_run
    @run_before = true
  end

  def after_run(success)
    @run_after = true
  end

  def before_enqueue
    @enqueue_before = true
  end

  def after_enqueue(success)
    @enqueue_after = true
  end

  def before_dequeue
    @dequeue_before = true
  end

  def after_dequeue(success)
    @dequeue_after = true
  end
end
