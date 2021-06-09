class SendEmailOnForJob
  include Mel::On

  getter sent : Bool

  run_on "0 */2 * * *", for: 4.hours

  def initialize(@address : String)
    @sent = false
  end

  def run
    @sent = true
  end
end
