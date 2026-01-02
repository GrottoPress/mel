def be_enqueued(count : Int32? = nil, as type = nil)
  Mel::BeEnqueuedExpectation.new(count, type)
end

def be_enqueued(count : Int, as type = nil)
  Mel::BeEnqueuedExpectation.new(count.to_i, type)
end

struct Mel::BeEnqueuedExpectation
  def initialize(@count : Int32? = nil, @type : Mel::Task.class | Nil = nil)
  end

  def self.new(count : Int, type = nil)
    new(count.to_i, type)
  end

  def match(job : Mel::Job::Template.class)
    count = Mel::Task.find(-1).try &.count do |task|
      next false unless task.job.class == job
      @type.nil? || task.class <= @type.not_nil!
    end

    return false if count.nil?
    @count.nil? ? count > 0 : count == @count
  end

  def failure_message(job : Mel::Job::Template.class)
    "Expected #{job} to be enqueued#{failure_message_suffix}"
  end

  def negative_failure_message(job : Mel::Job::Template.class)
    "Expected #{job} to not be enqueued#{failure_message_suffix}"
  end

  private def failure_message_suffix
    times_part = @count == 1 ? "once" : "#{@count} times"
    count_part = @count.nil? ? "" : " exactly #{times_part}"
    type_part = @type.nil? ? "" : " as #{@type}"

    "#{count_part}#{type_part}"
  end
end
