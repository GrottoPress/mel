module Mel::Task::CallbackHelpers
  macro included
    private def do_before_run : Bool
      job.before_run
      true
    rescue error
      log_callback_failed("before_run", error)
      false
    end

    private def do_after_run(success) : Bool
      job.after_run(success)
      true
    rescue error
      log_callback_failed("after_run", error)
      false
    end

    private def do_before_enqueue : Bool
      job.before_enqueue
      true
    rescue error
      log_callback_failed("before_enqueue", error)
      false
    end

    private def do_after_enqueue(success) : Bool
      job.after_enqueue(success)
      true
    rescue error
      log_callback_failed("after_enqueue", error)
      false
    end

    private def do_before_dequeue : Bool
      job.before_dequeue
      true
    rescue error
      log_callback_failed("before_dequeue", error)
      false
    end

    private def do_after_dequeue(success) : Bool
      job.after_dequeue(success)
      true
    rescue error
      log_callback_failed("after_dequeue", error)
      false
    end
  end
end
