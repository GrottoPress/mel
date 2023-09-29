struct Mel::Progress
  struct Report
    getter id : String
    getter description : String
    getter value : Int32

    def initialize(@id, @description, value)
      @value = value.to_i
    end

    def self.new(hash : Hash(String, _))
      new(hash["id"], hash["description"], hash["value"])
    end

    def self.new(row : Indexable)
      new row.each_slice(2).to_h
    end

    def started? : Bool
      pending? || running?
    end

    def pending? : Bool
      value == Progress::START
    end

    def running? : Bool
      Progress::START < value < Progress::END
    end

    def ended? : Bool
      success? || failure?
    end

    def success? : Bool
      value >= Progress::END
    end

    def failure? : Bool
      value < Progress::START
    end

    def self.find(id : String, redis = nil) : self?
      find({id}).try(&.first?)
    end

    def self.find(ids : Indexable, redis = nil) : Array(Mel::Progress::Report)?
      return if ids.empty?
      rows = Query.get(ids, redis)

      reports = rows.each.map(&.as(Array).map &.as(String)).compact_map do |row|
        new(row) if row.size == 6
      end.to_a

      reports unless reports.empty?
    end

    protected def save(redis = nil)
      Query.new(id).set(value, description, redis)
    end
  end
end
