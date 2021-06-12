class SendEmailNowJob
  include Mel::Job::Now

  getter sent : Bool

  def initialize(@address : String)
    @sent = false
  end

  def run
    @sent = true
  end
end
