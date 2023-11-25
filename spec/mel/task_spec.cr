require "../spec_helper"

describe Mel::Task do
  describe "#run" do
    it "retries failed task" do
      id = "1001"

      FailedJob.run(id, retries: 1)

      task = Mel::InstantTask.find(id, delete: true)
      task.try(&.attempts).should eq(0)
      Mel.sync(task)
      task.try(&.attempts).should eq(1)

      task = Mel::InstantTask.find(id, delete: true)
      task.try(&.attempts).should eq(1)
      Mel.sync(task)
      task.try(&.attempts).should eq(2)

      Mel::InstantTask.find(id).should be_nil
    end

    it "retries failed tasks with backoffs" do
      id = "1001"

      FailedJob.run(id, retries: {1.minute, 2.minutes})

      Mel.settings.worker_id = 7

      Timecop.freeze(Time.local) do
        Mel.start_and_stop(4)
        Mel::InstantTask.find(id).should_not be_nil
      end

      Timecop.travel(1.minute.from_now) do
        Mel.start_and_stop
        Mel::InstantTask.find(id).should_not be_nil
      end

      Timecop.travel(2.minutes.from_now) do
        Mel.start_and_stop
        Mel::InstantTask.find(id).should_not be_nil
      end

      Timecop.travel(3.minutes.from_now) do
        Mel.start_and_stop
        Mel::InstantTask.find(id).should be_nil
      end
    end
  end

  it "does not retry beyond current schedule window" do
    id = "1001"

    FailedJob.run_every(2.minutes, id: id, retries: {1.minute, 2.minutes})

    Mel.settings.worker_id = 8

    Timecop.freeze(2.minutes.from_now) do
      Mel.start_and_stop
      Mel::PeriodicTask.find(id).should_not be_nil
    end

    Timecop.freeze(3.minutes.from_now) do
      Mel.start_and_stop
      # Expect failed task to NOT be retried
      Mel::PeriodicTask.find(id).try(&.attempts.> 0).should be_false
    end
  end

  it "retries beyond current schedule window if task not rescheduled" do
    id = "1001"

    FailedJob.run_every(
      2.minutes,
      for: 2.minutes, # Ensures task is not rescheduled
      id: id,
      retries: {1.minute, 2.minutes}
    )

    Mel.settings.worker_id = 9

    Timecop.freeze(2.minutes.from_now) do
      Mel.start_and_stop
      Mel::PeriodicTask.find(id).should_not be_nil
    end

    Timecop.freeze(3.minutes.from_now) do
      Mel.start_and_stop
      # Expect failed task to be retried
      Mel::PeriodicTask.find(id).try(&.attempts.> 0).should be_true
    end
  end

  describe "#enqueue" do
    it "does not enqueue same task more than once" do
      address = "user@domain.tld"
      id = "1001"

      SendEmailJob.run(id, address: address)
      SendEmailJob.run(id, address: "aa@bb.cc")
      SendEmailJob.run(id, address: "dd@ee.ff")

      Mel::InstantTask.find(-1).try(&.size).should eq(1)

      Mel::InstantTask.find(id)
        .try(&.job.as(SendEmailJob).address)
        .should(eq address)
    end

    it "can overwrite existing task" do
      address = "user@domain.tld"
      id = "1001"

      SendEmailJob.run(id, force: true, address: "aa@bb.cc")
      SendEmailJob.run(id, force: true, address: "dd@ee.ff")
      SendEmailJob.run(id, force: true, address: address)

      Mel::InstantTask.find(-1).try(&.size).should eq(1)

      Mel::InstantTask.find(id)
        .try(&.job.as(SendEmailJob).address)
        .should(eq address)
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

  describe ".find_pending" do
    it "retrieves pending tasks" do
      address = "user@domain.tld"

      SendEmailJob.run(address: address)
      SendEmailJob.run(address: address)
      SendEmailJob.run(address: address)

      Mel.settings.worker_id = 5

      Mel::InstantTask.find_pending.should be_nil
      Mel::PeriodicTask.find_pending.should be_nil
      Mel::CronTask.find_pending.should be_nil
      Mel::Task.find_pending.should be_nil

      Mel::InstantTask.find(2, delete: nil).try(&.size).should eq(2)
      Mel::InstantTask.find(-1).try(&.size).should eq(1)

      Mel::InstantTask.find_pending.try(&.size).should eq(2)
      Mel::InstantTask.find_pending(1).try(&.size).should eq(1)

      Mel::PeriodicTask.find_pending.should be_nil
      Mel::CronTask.find_pending.should be_nil
      Mel::Task.find_pending.should_not be_nil
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
