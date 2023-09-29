struct Mel::Progress
  struct Report
    include JSON::Serializable

    getter id : String
    getter description : String
    getter value : Int32

    def initialize(@id, @description, value : Int)
      @value = value.to_i
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
  end
end
