require "../../spec_helper"

describe Mel::Job::Recurring do
  it "runs every given period" do
    address = "user@domain.tld"
    id = "1001"

    SendEmailRecurringJob.run_every(-2.hours, id: id, address: address)

    Time::Location.local = Time::Location.load("Europe/Berlin")

    (1..10).each do |hour|
      Timecop.travel(hour.hours.from_now) do
        task = Mel::PeriodicTask.find(id, delete: hour.even?)
        Mel.sync(task)

        task.try(&.job.as(SendEmailRecurringJob).sent).should eq(hour.even?)
      end
    end

    Mel::PeriodicTask.find(id).should be_a(Mel::PeriodicTask)
  end

  it "runs on given schedule" do
    address = "user@domain.tld"
    id = "1001"
    schedule = "0 */2 * * *"

    cron = CronParser.new(schedule)

    SendEmailRecurringJob.run_on(schedule, id: id, address: address)

    Timecop.travel(time = cron.next) do
      task = Mel::CronTask.find(id, delete: true)
      Mel.sync(task)
      task.try(&.job.as(SendEmailRecurringJob).sent).should be_true
    end

    Timecop.travel(time + 1.hour) do
      task = Mel::CronTask.find(id)
      Mel.sync(task)
      task.try(&.job.as(SendEmailRecurringJob).sent).should be_false
    end

    Timecop.travel(time = cron.next(time)) do
      task = Mel::CronTask.find(id, delete: true)
      Mel.sync(task)
      task.try(&.job.as(SendEmailRecurringJob).sent).should be_true
    end

    Timecop.travel(time + 1.hour) do
      task = Mel::CronTask.find(id)
      Mel.sync(task)
      task.try(&.job.as(SendEmailRecurringJob).sent).should be_false
    end

    Timecop.travel(time = cron.next(time)) do
      task = Mel::CronTask.find(id, delete: true)
      Mel.sync(task)
      task.try(&.job.as(SendEmailRecurringJob).sent).should be_true
    end

    Mel::CronTask.find(id).should be_a(Mel::CronTask)
  end
end
