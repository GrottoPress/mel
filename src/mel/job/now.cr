module Mel::Job::Now
  macro included
    include Mel::Job::Instant

    def self.time : Time
      Time.local
    end
  end
end
