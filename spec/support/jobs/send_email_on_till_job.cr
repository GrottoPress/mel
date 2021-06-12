class SendEmailOnTillJob
  include Mel::Job::On

  getter sent : Bool

  run_on "0 */2 * * *", till: 4.hours.from_now

  def initialize(@address : String)
    @sent = false
  end

  def run
    @sent = true
  end
end
