class SendEmailNowJob
  include Mel::Now

  getter sent : Bool

  def initialize(@address : String)
    @sent = false
  end

  def run
    @sent = true
  end
end
