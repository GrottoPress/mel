module Mel::Task::LogHelpers
  macro included
    private def log_enqueueing : Nil
      Mel.log.info &.emit("Enqueueing task...", task: to_json)
    end

    private def log_enqueued : Nil
      Mel.log.info &.emit("Task enqueued successfully", task: to_json)
    end

    private def log_dequeueing : Nil
      Mel.log.info &.emit("Dequeueing task...", task: to_json)
    end

    private def log_dequeued : Nil
      Mel.log.info &.emit("Task dequeued successfully", task: to_json)
    end

    private def log_not_due : Nil
      Mel.log.notice &.emit("Task not yet due. Aborting...", task: to_json)
    end

    private def log_running : Nil
      if due?
        Mel.log.info &.emit("Running task...", task: to_json)
      else
        Mel.log.notice &.emit("Running task before schedule...", task: to_json)
      end
    end

    private def log_ran : Nil
      Mel.log.info &.emit("Task complete", task: to_json)
    end

    private def log_errored(error) : Nil
      Mel.log.warn(
        exception: error,
        &.emit("Task errored. Retrying...", task: to_json)
      )
    end

    private def log_failed : Nil
      Mel.log.error &.emit(
        "Task failed after #{attempts} attempts",
        task: to_json
      )
    end

    private def log_scheduling : Nil
      Mel.log.info &.emit("Recheduling recurring task...", task: to_json)
    end

    private def log_scheduled : Nil
      Mel.log.info &.emit("Recurring task rescheduled", task: to_json)
    end
  end
end
