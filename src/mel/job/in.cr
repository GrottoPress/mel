module Mel::Job::In
  macro included
    include Mel::Job::Instant
  end

  private macro run_in(period)
    run_in { {{ period }} }
  end

  private macro run_in
    protected def time : Time
      {{ yield }}.from_now
    end
  end
end