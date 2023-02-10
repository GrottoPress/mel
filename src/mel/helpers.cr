module Mel::Helpers
  macro included
    private def raise_or(error, value = nil)
      Mel.settings.error_handler.call(error)
      Mel.settings.rescue_errors? ? value : raise error
    end
  end
end
