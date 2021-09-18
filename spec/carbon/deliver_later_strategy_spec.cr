require "../spec_helper"

describe Mel::Carbon::DeliverLaterStrategy do
  it "sends email" do
    email = WelcomeEmail.new("Mary", "mary@domain.tld")

    Mel.settings.worker_id = 6

    email.deliver_later
    Mel.start_and_stop
    email.should be_delivered
  end
end
