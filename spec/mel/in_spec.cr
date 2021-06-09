require "../spec_helper"

describe Mel::In do
  it "runs after a given period" do
    address = "user@domain.tld"
    id = "1001"

    SendEmailInJob.run(id, address: address)

    Time::Location.local = Time::Location.load("Europe/Berlin")

    Timecop.travel(1.hour.from_now) do
      task = Mel::InstantTask.find(id)
      Mel.sync(task)
      task.try(&.job.as(SendEmailInJob).sent).should be_false
    end

    Timecop.travel(2.hours.from_now) do
      task = Mel::InstantTask.find(id, delete: true)
      Mel.sync(task)
      task.try(&.job.as(SendEmailInJob).sent).should be_true
    end

    Mel::InstantTask.find(id).should be_nil
  end
end
