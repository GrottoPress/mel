struct SendEmailAtJob
  include Mel::Job::At

  @[JSON::Field(ignore: true)]
  getter sent = false

  def initialize(@address : String)
  end

  def run
    @sent = true
  end
end
