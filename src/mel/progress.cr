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

  def move(to value : Int, redis = nil)
    value = value.clamp(FAIL, END)
    Report.new(id, @description, value).save(redis)
  end

  def self.track(id : String, redis = nil)
    Report.find(id, redis)
  end

  struct Report
    include JSON::Serializable

    getter id : String
    getter description : String
    getter value : Int32

    def initialize(@id, @description, value)
      @value = value.to_i
    end

    def success? : Bool
      value >= Progress::END
    end

    def failure? : Bool
      value < Progress::START
    end

    def moving? : Bool
      Progress::END > value >= Progress::START
    end

    def self.find(id : String, redis = nil) : self?
      query = Query.new(id)
      values = redis ? query.get(redis).as(Array) : query.get.as(Array)

      values[1]?.try(&.as? String).try do |description|
        values[3]?.try(&.as? String).try do |id|
          values[5]?.try(&.as? String).try do |value|
            new(id, description, value)
          end
        end
      end
    end

    protected def save(redis = nil)
      query = Query.new(id)

      redis ?
        query.set(value, description, redis) :
        query.set(value, description)
    end
  end
end
