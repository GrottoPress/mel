class SendEmailEveryTillJob
  include Mel::Every

  getter sent : Bool

  run_every 2.hours, till: 5.hours.from_now

  def initialize(@address : String)
    @sent = false
  end

  def run
    @sent = true
  end
end
