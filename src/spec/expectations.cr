def be_enqueued(as type = nil)
  Mel::BeEnqueuedExpectation.new(type)
end

def be_enqueued(count : Int, as type = nil)
  Mel::BeEnqueuedExpectation.new(count, type)
end

def be_enqueued(id : String, as type = nil)
  Mel::BeEnqueuedExpectation.new(id, type)
end

struct Mel::BeEnqueuedExpectation
  @count : Int32?
  @id : String?

  def initialize(@type : Mel::Task.class | Nil = nil)
  end

  def initialize(count : Int, @type : Mel::Task.class | Nil = nil)
    @count = count.to_i
  end

  def initialize(@id : String, @type : Mel::Task.class | Nil = nil)
  end

  def match(job : Mel::Job::Template.class)
    find = @id.nil? ? -1 : {@id.not_nil!} # ameba:disable Lint/NotNil

    count = Mel::Task.find(find).try &.count do |task|
      next false unless task.job.class == job
      @type.nil? || task.class <= @type.not_nil! # ameba:disable Lint/NotNil
    end

    return false if count.nil?
    @count.nil? ? count > 0 : count == @count
  end

  def failure_message(job : Mel::Job::Template.class)
    "Expected #{job} to be enqueued#{failure_message_suffix}"
  end

  def negative_failure_message(job : Mel::Job::Template.class)
    "Expected #{job} not to be enqueued#{failure_message_suffix}"
  end

  private def failure_message_suffix
    times_part = @count == 1 ? "once" : "#{@count} times"
    count_part = @count.nil? ? "" : " exactly #{times_part}"
    type_part = @type.nil? ? "" : " as #{@type}"

    "#{count_part}#{type_part}"
  end
end
