class SendEmailAtJob
  include Mel::Job::At

  getter sent : Bool

  run_at 2.hours.from_now

  def initialize(@address : String)
    @sent = false
  end

  def run
    @sent = true
  end
end
