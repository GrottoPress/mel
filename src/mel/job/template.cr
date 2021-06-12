module Mel::Job::Template
  macro included
    include Mel::Job

    protected def time : Time
    end
  end
end
