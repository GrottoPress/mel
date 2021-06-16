struct SendEmailAtJob
  include Mel::Job::At

  @[JSON::Field(ignore: true)]
  getter sent = false

  run_at 2.hours.from_now

  def initialize(@address : String)
  end

  def run
    @sent = true
  end
end
