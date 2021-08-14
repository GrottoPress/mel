module Mel::Job::Instant
  macro included
    include Mel::Job::At
    include Mel::Job::In
    include Mel::Job::Now
  end
end
