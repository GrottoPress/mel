module Mel::At
  macro included
    include Mel::Instant
  end

  private macro run_at(time)
    run_at { {{ time }} }
  end

  private macro run_at
    protected def time : Time
      {{ yield }}
    end
  end
end
