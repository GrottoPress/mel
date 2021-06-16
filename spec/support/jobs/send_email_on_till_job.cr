struct SendEmailOnTillJob
  include Mel::Job::On

  @[JSON::Field(ignore: true)]
  getter sent = false

  run_on "0 */2 * * *", till: 4.hours.from_now

  def initialize(@address : String)
  end

  def run
    @sent = true
  end
end
