struct Mel::Progress
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
