class SendEmailEveryJob
  include Mel::Every

  getter sent : Bool

  run_every -2.hours

  def initialize(@address : String)
    @sent = false
  end

  def run
    @sent = true
  end
end
