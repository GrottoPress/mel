struct Mel::Progress
  include JSON::Serializable

  START = 0
  END = 100
  FAIL = -1

  getter :id

  def initialize(@id : String, @description : String)
  end

  def succeed(store = nil)
    move(END, store)
  end

  def fail(store = nil)
    move(FAIL, store)
  end

  def start(store = nil)
    move(START, store)
  end

  def move(to value : Int, store = nil)
    value = value.clamp(FAIL, END)
    Mel.settings.store.try &.set_progress(id, value, @description, store)
  end

  def self.start(id : String, description : String, store = nil) : self
    new(id, description).tap(&.start store)
  end

  def self.track(id : String)
    track({id}).try(&.first?)
  end

  def self.track(ids : Indexable)
    Mel.settings.store.try &.get_progress(ids).try &.map do |value|
      Report.from_json(value)
    end.try do |reports|
      reports unless reports.empty?
    end
  end
end
