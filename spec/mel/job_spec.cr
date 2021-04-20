require "../spec_helper"

describe Mel::Job do
  describe ".run_now" do
    it "runs instantly" do
      address = "user@domain.tld"
      id = "1001"

      SendEmailJob.run(id, address: address)

      Time::Location.local = Time::Location.load("Europe/Berlin")

      task = Mel::InstantTask.find(id, delete: true)
      sync(task)
      task.try(&.job.as(SendEmailJob).sent).should be_true

      Mel::InstantTask.find(id).should be_nil
    end
  end

  describe ".run_in" do
    it "runs after a given period" do
      address = "user@domain.tld"
      id = "1001"

      SendEmailJob.run_in(2.hours, id, address: address)

      Time::Location.local = Time::Location.load("Europe/Berlin")

      Timecop.travel(1.hour.from_now) do
        task = Mel::InstantTask.find(id)
        sync(task)
        task.try(&.job.as(SendEmailJob).sent).should be_false
      end

      Timecop.travel(2.hours.from_now) do
        task = Mel::InstantTask.find(id, delete: true)
        sync(task)
        task.try(&.job.as(SendEmailJob).sent).should be_true
      end

      Mel::InstantTask.find(id).should be_nil
    end
  end

  describe ".run_at" do
    it "runs at given time" do
      address = "user@domain.tld"
      id = "1001"

      SendEmailJob.run_at(2.hours.from_now, id, address: address)

      Time::Location.local = Time::Location.load("Europe/Berlin")

      Timecop.travel(1.hour.from_now) do
        task = Mel::InstantTask.find(id)
        sync(task)
        task.try(&.job.as(SendEmailJob).sent).should be_false
      end

      Timecop.travel(2.hours.from_now) do
        task = Mel::InstantTask.find(id, delete: true)
        sync(task)
        task.try(&.job.as(SendEmailJob).sent).should be_true
      end

      Mel::InstantTask.find(id).should be_nil
    end
  end

  describe ".run_every" do
    it "runs every given period" do
      address = "user@domain.tld"
      id = "1001"

      SendEmailJob.run_every(-2.hours, id: id, address: address)

      Time::Location.local = Time::Location.load("Europe/Berlin")

      (1..10).each do |hour|
        Timecop.travel(hour.hours.from_now) do
          task = Mel::PeriodicTask.find(id, delete: hour.even?)
          sync(task)

          task.try(&.job.as(SendEmailJob).sent).should eq(hour.even?)
        end
      end

      Mel::PeriodicTask.find(id).should be_a(Mel::PeriodicTask)
    end

    it "deletes task after given time" do
      address = "user@domain.tld"
      id = "1001"

      SendEmailJob.run_every(2.hours, for: 5.hours, id: id, address: address)

      Time::Location.local = Time::Location.load("Europe/Berlin")

      (1..4).each do |hour|
        Timecop.travel(hour.hours.from_now) do
          task = Mel::PeriodicTask.find(id, delete: hour.even?)
          sync(task)

          task.try(&.job.as(SendEmailJob).sent).should eq(hour.even?)
        end
      end

      Mel::PeriodicTask.find(id).should be_nil
    end
  end

  describe ".run_on" do
    it "runs on given schedule" do
      address = "user@domain.tld"
      id = "1001"
      schedule = "0 */2 * * *"
      cron = CronParser.new(schedule)

      SendEmailJob.run_on(schedule, id: id, address: address)

      Timecop.travel(time = cron.next) do
        task = Mel::CronTask.find(id, delete: true)
        sync(task)
        task.try(&.job.as(SendEmailJob).sent).should be_true
      end

      Timecop.travel(time + 1.hour) do
        task = Mel::CronTask.find(id)
        sync(task)
        task.try(&.job.as(SendEmailJob).sent).should be_false
      end

      Timecop.travel(time = cron.next(time)) do
        task = Mel::CronTask.find(id, delete: true)
        sync(task)
        task.try(&.job.as(SendEmailJob).sent).should be_true
      end

      Timecop.travel(time + 1.hour) do
        task = Mel::CronTask.find(id)
        sync(task)
        task.try(&.job.as(SendEmailJob).sent).should be_false
      end

      Timecop.travel(time = cron.next(time)) do
        task = Mel::CronTask.find(id, delete: true)
        sync(task)
        task.try(&.job.as(SendEmailJob).sent).should be_true
      end

      Mel::CronTask.find(id).should be_a(Mel::CronTask)
    end

    it "deletes task after given time" do
      address = "user@domain.tld"
      id = "1001"
      schedule = "0 */2 * * *"
      cron = CronParser.new(schedule)

      SendEmailJob.run_on(schedule, for: 4.hours, id: id, address: address)

      Timecop.travel(time = cron.next) do
        task = Mel::CronTask.find(id, delete: true)
        sync(task)
        task.try(&.job.as(SendEmailJob).sent).should be_true
      end

      Timecop.travel(cron.next(time)) do
        task = Mel::CronTask.find(id, delete: true)
        sync(task)
        task.try(&.job.as(SendEmailJob).sent).should be_true
      end

      Timecop.travel(4.hours.from_now) do
        Mel::CronTask.find(id).should be_nil
      end
    end
  end

  describe "#before_run" do
    it "runs" do
      id = "1001"
      address = "user@domain.tld"

      SendEmailJob.run(id: id, address: address)
      task = Mel::InstantTask.find(id)

      task.try(&.job.as(SendEmailJob).run_before).should be_false
      sync(task)
      task.try(&.job.as(SendEmailJob).run_before).should be_true
    end

    it "runs even if task fails" do
      id = "1001"

      FailedJob.run(id: id, retries: 0)
      task = Mel::InstantTask.find(id)

      task.try(&.job.as(FailedJob).run_before).should be_false
      sync(task)
      task.try(&.job.as(FailedJob).run_before).should be_true
    end
  end

  describe "#after_run" do
    it "runs" do
      id = "1001"
      address = "user@domain.tld"

      SendEmailJob.run(id: id, address: address)
      task = Mel::InstantTask.find(id)

      task.try(&.job.as(SendEmailJob).run_after).should be_false
      sync(task)
      task.try(&.job.as(SendEmailJob).run_after).should be_true
    end

    it "runs even if task fails" do
      id = "1001"

      FailedJob.run(id: id, retries: 0)
      task = Mel::InstantTask.find(id)

      task.try(&.job.as(FailedJob).run_after).should be_false
      sync(task)
      task.try(&.job.as(FailedJob).run_after).should be_true
    end
  end

  describe "#before_enqueue" do
    it "runs" do
      id = "1001"
      address = "user@domain.tld"

      SendEmailJob.run(id: id, address: address)

      task = Mel::InstantTask.find(id)
      task.try(&.job.as(SendEmailJob).enqueue_before).should be_true
    end

    pending "runs even if enqueue fails" do
    end
  end

  describe "#after_enqueue" do
    it "runs" do
      id = "1001"
      address = "user@domain.tld"

      SendEmailJob.run(id: id, address: address)

      task = Mel::InstantTask.find(id)
      task.try(&.enqueue)
      task.try(&.job.as(SendEmailJob).enqueue_after).should be_true
    end

    pending "runs even if enqueue fails" do
    end
  end

  describe "#before_dequeue" do
    it "runs" do
      id = "1001"
      address = "user@domain.tld"

      SendEmailJob.run(id: id, address: address)
      task = Mel::InstantTask.find(id)

      task.try(&.job.as(SendEmailJob).dequeue_before).should be_false
      task.try(&.dequeue)
      task.try(&.job.as(SendEmailJob).dequeue_before).should be_true
    end

    pending "runs even if dequeue fails" do
    end
  end

  describe "#after_dequeue" do
    it "runs" do
      id = "1001"
      address = "user@domain.tld"

      SendEmailJob.run(id: id, address: address)
      task = Mel::InstantTask.find(id)

      task.try(&.job.as(SendEmailJob).dequeue_after).should be_false
      task.try(&.dequeue)
      task.try(&.job.as(SendEmailJob).dequeue_after).should be_true
    end

    pending "runs even if dequeue fails" do
    end
  end

  describe "#run" do
    it "schedules bulk jobs" do
      id = "1001"
      max = 10

      CounterJob.run(id: id, max: max)
      task = Mel::InstantTask.find(id, delete: true)

      task.should_not be_nil
      sync(task)
      Mel::InstantTask.find(-1).try(&.size).should eq(max)
    end
  end
end
