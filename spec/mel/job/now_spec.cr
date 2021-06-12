require "../../spec_helper"

describe Mel::Job::Now do
  it "runs now" do
    address = "user@domain.tld"
    id = "1001"

    SendEmailNowJob.run(id, address: address)

    Time::Location.local = Time::Location.load("Europe/Berlin")

    task = Mel::InstantTask.find(id, delete: true)
    Mel.sync(task)
    task.try(&.job.as(SendEmailNowJob).sent).should be_true

    Mel::InstantTask.find(id).should be_nil
  end
end
