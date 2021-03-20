class SendEmailJob
  include Mel::Job

  getter sent : Bool

  def initialize(@address : String)
    @sent = false
  end

  def run
    @sent = true
  end
end
