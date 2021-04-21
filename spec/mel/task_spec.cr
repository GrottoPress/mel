require "../spec_helper"

describe Mel::Task do
  describe "#run" do
    it "retries failed task" do
      id = "1001"

      FailedJob.run(id, retries: 1)

      task = Mel::InstantTask.find(id, delete: true)
      task.try(&.attempts).should eq(0)
      sync(task)
      task.try(&.attempts).should eq(1)

      task = Mel::InstantTask.find(id, delete: true)
      task.try(&.attempts).should eq(1)
      sync(task)
      task.try(&.attempts).should eq(2)

      Mel::InstantTask.find(id).should be_nil
    end
  end

  describe "#enqueue" do
    it "does not enqueue same task more than once" do
      address = "user@domain.tld"
      id = "1001"

      SendEmailJob.run(id, address: address)
      SendEmailJob.run(id, address: address)
      SendEmailJob.run(id, address: address)

      Mel::InstantTask.find(-1).try(&.size).should eq(1)
    end

    it "enqueues multiple similar tasks with different IDs" do
      address = "user@domain.tld"

      SendEmailJob.run(address: address)
      SendEmailJob.run(address: address)
      SendEmailJob.run(address: address)

      Mel::InstantTask.find(-1).try(&.size).should eq(3)
    end
  end

  describe "#dequeue" do
    it "removes task from redis" do
      id = "1001"
      address = "user@domain.tld"

      SendEmailJob.run(address: address)
      SendEmailJob.run_every(10.minutes, id: id, address: address)
      SendEmailJob.run_on("0 2 * * *", for: 1.week, address: address)

      Mel::Task.find(-1).try(&.size).should eq(3)
      Mel::PeriodicTask.find(-1).try(&.size).should eq(1)

      Mel::PeriodicTask.find(id).try(&.dequeue)

      Mel::Task.find(-1).try(&.size).should eq(2)
      Mel::PeriodicTask.find(-1).should be_nil
    end
  end

  describe ".find" do
    it "returns the correct count" do
      address = "user@domain.tld"

      SendEmailJob.run(address: address)
      SendEmailJob.run(address: address)
      SendEmailJob.run(address: address)

      Mel::InstantTask.find(1).try(&.size).should eq(1)
      Mel::InstantTask.find(2).try(&.size).should eq(2)
      Mel::InstantTask.find(3).try(&.size).should eq(3)
      Mel::InstantTask.find(4).try(&.size).should eq(3)
      Mel::InstantTask.find(-1).try(&.size).should eq(3)
    end
  end

  describe ".find_lt" do
    it "returns all tasks whose times are past due" do
      address = "user@domain.tld"
      later = 2.hour.from_now

      SendEmailJob.run(address: address)
      SendEmailJob.run_in(1.hour, address: address)
      SendEmailJob.run_at(later, address: address)

      Mel::InstantTask.find(-1).try(&.size).should eq(3)
      Mel::InstantTask.find_lt(later).try(&.size).should eq(2)
      Mel::InstantTask.find_lt(later, 1).try(&.size).should eq(1)
    end
  end

  describe ".find_lte" do
    it "returns all tasks whose times are either due or past due" do
      address = "user@domain.tld"
      later = 2.hours.from_now

      SendEmailJob.run(address: address)
      SendEmailJob.run_at(later, address: address)
      SendEmailJob.run_at(4.hours.from_now, address: address)

      Mel::InstantTask.find(-1).try(&.size).should eq(3)
      Mel::InstantTask.find_lte(later).try(&.size).should eq(2)
      Mel::InstantTask.find_lte(later, 1).try(&.size).should eq(1)
    end
  end
end
