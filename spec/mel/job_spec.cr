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

      SendEmailJob.run_every(2.hours, id: id, address: address)

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
end
