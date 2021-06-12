module Mel::Job::Recurring
  macro included
    include Mel::Job::Template

    protected def end_time : Time?
    end
  end
end
