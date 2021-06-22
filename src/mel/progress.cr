struct Mel::Progress
  include JSON::Serializable

  getter :id

  private START = 0
  private END = 100
  private FAIL = -1

  def initialize(@id : String)
    @query = Query.new(@id)
  end

  def succeed(redis = nil)
    track(END, redis)
  end

  def fail(redis = nil)
    track(FAIL, redis)
  end

  def success?(redis = nil) : Bool
    track(redis) >= END
  end

  def failure?(redis = nil) : Bool
    track(redis) < START
  end

  def tracking?(redis = nil) : Bool
    END > track(redis) >= START
  end

  def track(redis = nil)
    redis ? @query.get(redis) : @query.get
  end

  def track(to value : Number, redis = nil)
    value = END if value > END
    value = FAIL if value < START
    redis ? @query.set(value, redis) : @query.set(value)
  end
end
