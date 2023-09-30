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
    Query.new(id).set(value, @description, redis)
  end

  def self.start(id : String, description : String, redis = nil) : self
    new(id, description).tap(&.start redis)
  end

  def self.track(id : String)
    track({id}).try(&.first?)
  end

  def self.track(ids : Indexable)
    Query.get(ids).try &.compact_map do |value|
      Report.from_json(value.as(String)) if value
    end.try do |reports|
      reports unless reports.empty?
    end
  end
end
