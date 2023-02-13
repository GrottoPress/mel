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

  def self.track(ids : Indexable, redis = nil)
    Report.find(ids, redis)
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
      find([id]).try(&.first?)
    end

    def self.find(ids : Indexable, redis = nil) : Array(Mel::Progress::Report)?
      return if ids.empty?

      rows = redis ? Query.get(ids, redis) : Query.get(ids)

      reports = rows.each.map(&.as(Array).map &.as(String)).map do |row|
        row[1]?.try do |description|
          row[3]?.try do |id|
            row[5]?.try do |value|
              new(id, description, value)
            end
          end
        end
      end.reject(Nil).to_a

      reports unless reports.empty?
    end

    protected def save(redis = nil)
      query = Query.new(id)

      redis ?
        query.set(value, description, redis) :
        query.set(value, description)
    end
  end
end
