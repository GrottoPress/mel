module Mel::Recurring
  macro included
    include Mel::Template

    protected def end_time : Time?
    end
  end
end
