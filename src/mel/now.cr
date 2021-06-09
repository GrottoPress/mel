module Mel::Now
  macro included
    include Mel::Instant

    protected def time : Time
      Time.local
    end
  end
end
