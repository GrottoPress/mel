struct SendEmailOnForJob
  include Mel::Job::On

  @[JSON::Field(ignore: true)]
  getter sent = false

  run_on "0 */2 * * *", for: 4.hours

  def initialize(@address : String)
  end

  def run
    @sent = true
  end
end
