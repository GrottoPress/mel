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
    move(END, redis)
  end

  def fail(redis = nil)
    move(FAIL, redis)
  end

  def success?(redis = nil) : Bool
    self.class.success? track(redis)
  end

  def self.success?(value : Number)
    value >= END
  end

  def failure?(redis = nil) : Bool
    track(redis) < START
  end

  def moving?(redis = nil) : Bool
    self.class.moving? track(redis)
  end

  def self.moving?(value : Number)
    END > value >= START
  end

  def track(redis = nil)
    redis ? @query.get(redis) : @query.get
  end

  def move(to value : Number, redis = nil)
    value = END if value > END
    value = FAIL if value < START
    redis ? @query.set(value, redis) : @query.set(value)
  end

  def forward(by value : Number, redis = nil)
    redis ? @query.increment(value, redis) : @query.increment(value)
  end

  def backward(by value : Number, redis = nil)
    redis ? @query.decrement(value, redis) : @query.decrement(value)
  end
end
