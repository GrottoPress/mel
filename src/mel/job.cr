module Mel::Job
  macro included
    include Mel::Job::Instant
    include Mel::Job::Recurring
  end
end
