module Mel::Task::LogHelpers
  macro included
    private def log_enqueueing : Nil
      Mel.log.info &.emit("Enqueueing task...", **log_args)
    end

    private def log_enqueued : Nil
      Mel.log.info &.emit("Task enqueued successfully", **log_args)
    end

    private def log_dequeueing : Nil
      Mel.log.info &.emit("Dequeueing task...", **log_args)
    end

    private def log_dequeued : Nil
      Mel.log.info &.emit("Task dequeued successfully", **log_args)
    end

    private def log_not_due : Nil
      Mel.log.notice &.emit("Task not yet due. Aborting...", **log_args)
    end

    private def log_running : Nil
      if due?
        Mel.log.info &.emit("Running task...", **log_args)
      else
        Mel.log.notice &.emit("Running task before schedule...", **log_args)
      end
    end

    private def log_ran : Nil
      Mel.log.info &.emit("Task complete", **log_args)
    end

    private def log_errored(error) : Nil
      Mel.log.warn(
        exception: error,
        &.emit("Task errored. Retrying...", **log_args)
      )
    end

    private def log_failed : Nil
      Mel.log.error &.emit("Task failed after #{attempts} attempts", **log_args)
    end

    private def log_scheduling : Nil
      Mel.log.info &.emit("Recheduling recurring task...", **log_args)
    end

    private def log_scheduled : Nil
      Mel.log.info &.emit("Recurring task rescheduled", **log_args)
    end

    private def log_callback_failed(callback, error) : Nil
      Mel.log.warn(
        exception: error,
        &.emit("Callback failed", **log_args, callback: callback)
      )
    end
  end
end
