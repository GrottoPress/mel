struct Mel::Progress
  include JSON::Serializable

  START = 0
  END = 100
  FAIL = -1

  getter :id

  def initialize(@id : String, @description : String)
  end

  def key : String
    Query.new(@id).key
  end

  def succeed(redis = nil)
    move(END, redis)
  end

  def fail(redis = nil)
    move(FAIL, redis)
  end

  def start(redis = nil)
    move(START, redis)
  end

  def move(to value : Int, redis = nil)
    value = value.clamp(FAIL, END)
    Report.new(id, @description, value).save(redis)
  end

  def self.start(id : String, description : String, redis = nil) : self
    new(id, description).tap(&.start redis)
  end

  def self.track(id : String, redis = nil)
    Report.find(id, redis)
  end

  def self.track(ids : Indexable, redis = nil)
    Report.find(ids, redis)
  end
end
