module Mel::Helpers
  macro included
    private def handle_error(error) : Nil
      Mel.settings.error_handler.call(error)
    end

    private def handle_exit(code, error) : Nil
      message = "Mel exited with code #{code}"
      return Mel.log.info &.emit(message) if code == 0 && error.nil?

      Mel.log.fatal(exception: error, &.emit(message))
      handle_error(error) if error
    end
  end
end
