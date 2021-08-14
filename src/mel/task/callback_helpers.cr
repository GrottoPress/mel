module Mel::Task::CallbackHelpers
  macro included
    include Mel::Helpers

    private def do_before_run : Bool
      job.before_run
      true
    rescue error
      log_callback_failed("before_run", error)
      raise_or(error, false)
    end

    private def do_after_run(success) : Bool
      job.after_run(success)
      true
    rescue error
      log_callback_failed("after_run", error)
      raise_or(error, false)
    end

    private def do_before_enqueue : Bool
      job.before_enqueue
      true
    rescue error
      log_callback_failed("before_enqueue", error)
      raise_or(error, false)
    end

    private def do_after_enqueue(success) : Bool
      job.after_enqueue(success)
      true
    rescue error
      log_callback_failed("after_enqueue", error)
      raise_or(error, false)
    end

    private def do_before_dequeue : Bool
      job.before_dequeue
      true
    rescue error
      log_callback_failed("before_dequeue", error)
      raise_or(error, false)
    end

    private def do_after_dequeue(success) : Bool
      job.after_dequeue(success)
      true
    rescue error
      log_callback_failed("after_dequeue", error)
      raise_or(error, false)
    end
  end
end
