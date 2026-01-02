def be_enqueued(as type : Mel::Task.class | Nil = nil)
  Mel::BeEnqueuedExpectation.new(type)
end

struct Mel::BeEnqueuedExpectation
  def initialize(@type : Mel::Task.class | Nil = nil)
  end

  def match(job : Mel::Job::Template.class)
    Mel::Task.find(-1).try &.any? do |task|
      next false unless task.job.class == job
      @type.nil? || task.class <= @type.not_nil!
    end
  end

  def failure_message(job : Mel::Job::Template.class)
    @type.try do |type|
      return "Expected #{job} to be enqueued as #{type}"
    end

    "Expected #{job} to be enqueued"
  end

  def negative_failure_message(job : Mel::Job::Template.class)
    @type.try do |type|
      return "Expected #{job} to not be enqueued as #{type}"
    end

    "Expected #{job} to not be enqueued"
  end
end
