require "../../spec_helper"

describe Mel::Job::Every do
  it "runs every given period" do
    address = "user@domain.tld"
    id = "1001"

    SendEmailEveryJob.run(id: id, address: address)

    Time::Location.local = Time::Location.load("Europe/Berlin")

    (1..10).each do |hour|
      Timecop.travel(hour.hours.from_now) do
        task = Mel::PeriodicTask.find(id, delete: hour.even?)
        Mel.sync(task)

        task.try(&.job.as(SendEmailEveryJob).sent).should eq(hour.even?)
      end
    end

    Mel::PeriodicTask.find(id).should be_a(Mel::PeriodicTask)
  end

  it "deletes task after given time" do
    address = "user@domain.tld"
    id = "1001"

    SendEmailEveryTillJob.run(id: id, address: address)

    Time::Location.local = Time::Location.load("Europe/Berlin")

    (1..4).each do |hour|
      Timecop.travel(hour.hours.from_now) do
        task = Mel::PeriodicTask.find(id, delete: hour.even?)
        Mel.sync(task)

        task.try(&.job.as(SendEmailEveryTillJob).sent).should eq(hour.even?)
      end
    end

    Mel::PeriodicTask.find(id).should be_nil
  end

  it "deletes task after given period" do
    address = "user@domain.tld"
    id = "1001"

    SendEmailEveryForJob.run(id: id, address: address)

    Time::Location.local = Time::Location.load("Europe/Berlin")

    (1..4).each do |hour|
      Timecop.travel(hour.hours.from_now) do
        task = Mel::PeriodicTask.find(id, delete: hour.even?)
        Mel.sync(task)

        task.try(&.job.as(SendEmailEveryForJob).sent).should eq(hour.even?)
      end
    end

    Mel::PeriodicTask.find(id).should be_nil
  end
end
