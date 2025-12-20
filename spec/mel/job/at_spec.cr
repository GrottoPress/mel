require "../../spec_helper"

describe Mel::Job::At do
  it "runs at given time" do
    address = "user@domain.tld"
    id = "1001"

    SendEmailAtJob.run_at(2.hours.from_now, id: id, address: address)

    Time::Location.local = Time::Location.load("Europe/Berlin")

    Timecop.travel(1.hour.from_now) do
      task = Mel::InstantTask.find(id)
      Mel.sync(task)
      task.try(&.job.as(SendEmailAtJob).sent?).should be_false
    end

    Timecop.travel(2.hours.from_now) do
      task = Mel::InstantTask.find(id, delete: true)
      Mel.sync(task)
      task.try(&.job.as(SendEmailAtJob).sent?).should be_true
    end

    Mel::InstantTask.find(id).should be_nil
  end
end
