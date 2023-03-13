module Mel::Helpers
  macro included
    private def handle_error(error) : Nil
      Mel.settings.error_handler.call(error)
    end
  end
end
