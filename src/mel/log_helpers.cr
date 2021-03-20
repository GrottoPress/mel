module Mel::LogHelpers
  macro included
    private def log_already_started : Nil
      log.notice { "Mel already started" }
    end

    private def log_not_started : Nil
      log.notice { "Cannot stop Mel. Not started" }
    end

    private def log_stopping : Nil
      log.info { "Mel stopping..." }
    end

    private def log_stopped : Nil
      log.info { "Mel stopped" }
    end

    private def log_waiting : Nil
      log.info { "Waiting on running tasks..." }
    end

    private def log_starting : Nil
      log.info { "Mel starting..." }
    end

    private def log_started : Nil
      log.info { "Mel started. Wating for tasks..." }
    end
  end
end
