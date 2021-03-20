class RetryJob
  include Mel::Job

  def run
    raise "Failed on purpose"
  end
end
