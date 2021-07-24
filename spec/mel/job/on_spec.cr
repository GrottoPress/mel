require "../../spec_helper"

describe Mel::Job::On do
  it "runs on given schedule" do
    address = "user@domain.tld"
    id = "1001"
    schedule = "0 */2 * * *"

    cron = CronParser.new(schedule)

    SendEmailOnJob.run_on(schedule, id: id, address: address)

    Timecop.travel(time = cron.next) do
      task = Mel::CronTask.find(id, delete: true)
      Mel.sync(task)
      task.try(&.job.as(SendEmailOnJob).sent).should be_true
    end

    Timecop.travel(time + 1.hour) do
      task = Mel::CronTask.find(id)
      Mel.sync(task)
      task.try(&.job.as(SendEmailOnJob).sent).should be_false
    end

    Timecop.travel(time = cron.next(time)) do
      task = Mel::CronTask.find(id, delete: true)
      Mel.sync(task)
      task.try(&.job.as(SendEmailOnJob).sent).should be_true
    end

    Timecop.travel(time + 1.hour) do
      task = Mel::CronTask.find(id)
      Mel.sync(task)
      task.try(&.job.as(SendEmailOnJob).sent).should be_false
    end

    Timecop.travel(time = cron.next(time)) do
      task = Mel::CronTask.find(id, delete: true)
      Mel.sync(task)
      task.try(&.job.as(SendEmailOnJob).sent).should be_true
    end

    Mel::CronTask.find(id).should be_a(Mel::CronTask)
  end

  it "deletes task after given time" do
    address = "user@domain.tld"
    id = "1001"
    schedule = "0 */2 * * *"

    cron = CronParser.new(schedule)

    SendEmailOnTillJob.run_on(
      schedule,
      till: 4.hours.from_now,
      id: id,
      address: address
    )

    Timecop.travel(time = cron.next) do
      task = Mel::CronTask.find(id, delete: true)
      Mel.sync(task)
      task.try(&.job.as(SendEmailOnTillJob).sent).should be_true
    end

    Timecop.travel(cron.next(time)) do
      task = Mel::CronTask.find(id, delete: true)
      Mel.sync(task)
      task.try(&.job.as(SendEmailOnTillJob).sent).should be_true
    end

    Timecop.travel(4.hours.from_now) do
      Mel::CronTask.find(id).should be_nil
    end
  end

  it "deletes task after given period" do
    address = "user@domain.tld"
    id = "1001"
    schedule = "0 */2 * * *"

    cron = CronParser.new(schedule)

    SendEmailOnForJob.run_on(schedule, for: 4.hours, id: id, address: address)

    Timecop.travel(time = cron.next) do
      task = Mel::CronTask.find(id, delete: true)
      Mel.sync(task)
      task.try(&.job.as(SendEmailOnForJob).sent).should be_true
    end

    Timecop.travel(cron.next(time)) do
      task = Mel::CronTask.find(id, delete: true)
      Mel.sync(task)
      task.try(&.job.as(SendEmailOnForJob).sent).should be_true
    end

    Timecop.travel(4.hours.from_now) do
      Mel::CronTask.find(id).should be_nil
    end
  end
end
