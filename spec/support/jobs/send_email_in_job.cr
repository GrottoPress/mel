struct SendEmailInJob
  include Mel::Job::In

  @[JSON::Field(ignore: true)]
  getter sent = false

  run_in 2.hours

  def initialize(@address : String)
  end

  def run
    @sent = true
  end
end
