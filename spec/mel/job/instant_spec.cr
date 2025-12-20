require "../../spec_helper"

describe Mel::Job::Instant do
  it "runs now" do
    address = "user@domain.tld"
    id = "1001"

    SendEmailInstantJob.run(id, address: address)

    Time::Location.local = Time::Location.load("Europe/Berlin")

    task = Mel::InstantTask.find(id, delete: true)
    Mel.sync(task)
    task.try(&.job.as(SendEmailInstantJob).sent?).should be_true

    Mel::InstantTask.find(id).should be_nil
  end

  it "runs at given time" do
    address = "user@domain.tld"
    id = "1001"

    SendEmailInstantJob.run_at(2.hours.from_now, id: id, address: address)

    Time::Location.local = Time::Location.load("Europe/Berlin")

    Timecop.travel(1.hour.from_now) do
      task = Mel::InstantTask.find(id)
      Mel.sync(task)
      task.try(&.job.as(SendEmailInstantJob).sent?).should be_false
    end

    Timecop.travel(2.hours.from_now) do
      task = Mel::InstantTask.find(id, delete: true)
      Mel.sync(task)
      task.try(&.job.as(SendEmailInstantJob).sent?).should be_true
    end

    Mel::InstantTask.find(id).should be_nil
  end

  it "runs after a given period" do
    address = "user@domain.tld"
    id = "1001"

    SendEmailInstantJob.run_in(2.hours, id: id, address: address)

    Time::Location.local = Time::Location.load("Europe/Berlin")

    Timecop.travel(1.hour.from_now) do
      task = Mel::InstantTask.find(id)
      Mel.sync(task)
      task.try(&.job.as(SendEmailInstantJob).sent?).should be_false
    end

    Timecop.travel(2.hours.from_now) do
      task = Mel::InstantTask.find(id, delete: true)
      Mel.sync(task)
      task.try(&.job.as(SendEmailInstantJob).sent?).should be_true
    end

    Mel::InstantTask.find(id).should be_nil
  end
end
