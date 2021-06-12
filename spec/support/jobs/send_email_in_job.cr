class SendEmailInJob
  include Mel::Job::In

  getter sent : Bool

  run_in 2.hours

  def initialize(@address : String)
    @sent = false
  end

  def run
    @sent = true
  end
end
