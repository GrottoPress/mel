module Mel::Recurring
  macro included
    include Mel::Job

    protected def end_time : Time?
    end
  end
end
