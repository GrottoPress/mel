struct SendEmailEveryJob
  include Mel::Job::Every

  @[JSON::Field(ignore: true)]
  getter sent = false

  def initialize(@address : String)
  end

  def run
    @sent = true
  end
end
