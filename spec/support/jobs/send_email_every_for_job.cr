struct SendEmailEveryForJob
  include Mel::Job::Every

  @[JSON::Field(ignore: true)]
  getter sent = false

  run_every 2.hours, for: 5.hours

  def initialize(@address : String)
  end

  def run
    @sent = true
  end
end
