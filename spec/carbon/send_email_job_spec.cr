require "../spec_helper"

describe Mel::Carbon::EmailJob do
  it "sends email" do
    email = WelcomeEmail.new("Mary", "mary@domain.tld")

    email.deliver_later
    Mel.start_and_stop
    email.should be_delivered
  end
end
