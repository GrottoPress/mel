class SendEmailOnJob
  include Mel::Job::On

  getter sent : Bool

  run_on "0 */2 * * *"

  def initialize(@address : String)
    @sent = false
  end

  def run
    @sent = true
  end
end
