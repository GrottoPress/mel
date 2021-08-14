module Mel::Job::Recurring
  macro included
    include Mel::Job::Every
    include Mel::Job::On
  end
end
