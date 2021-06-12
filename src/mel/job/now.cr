module Mel::Job::Now
  macro included
    include Mel::Job::Instant

    protected def time : Time
      Time.local
    end
  end
end
