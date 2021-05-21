class SendEmailJob
  include Mel::Job

  getter sent : Bool

  getter run_before : Bool = false
  getter run_after : Bool = false

  getter enqueue_before : Bool = false
  getter enqueue_after : Bool = false

  getter dequeue_before : Bool = false
  getter dequeue_after : Bool = false

  def initialize(@address : String)
    @sent = false
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
