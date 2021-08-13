struct SendEmailRecurringJob
  include Mel::Job::Recurring

  @[JSON::Field(ignore: true)]
  getter sent = false

  def initialize(@address : String)
  end

  def run
    @sent = true
  end
end
