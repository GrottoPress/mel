class SendEmailEveryJob
  include Mel::Job::Every

  getter sent : Bool

  run_every -2.hours

  def initialize(@address : String)
    @sent = false
  end

  def run
    @sent = true
  end
end
