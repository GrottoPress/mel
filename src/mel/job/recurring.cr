module Mel::Job::Recurring
  macro included
    include Mel::Job::Template

    def self.end_time : Time?
    end
  end
end
