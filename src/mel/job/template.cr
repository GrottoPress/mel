module Mel::Job::Template
  macro included
    include Mel::Job

    def self.time : Time
    end
  end
end
