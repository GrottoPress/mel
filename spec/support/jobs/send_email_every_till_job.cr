struct SendEmailEveryTillJob
  include Mel::Job::Every

  @[JSON::Field(ignore: true)]
  getter sent = false

  run_every 2.hours, till: 5.hours.from_now

  def initialize(@address : String)
  end

  def run
    @sent = true
  end
end
