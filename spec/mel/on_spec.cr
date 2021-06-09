require "../spec_helper"

describe Mel::On do
  it "runs on given schedule" do
    address = "user@domain.tld"
    id = "1001"
    cron = CronParser.new("0 */2 * * *")

    SendEmailOnJob.run(id: id, address: address)

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
    cron = CronParser.new("0 */2 * * *")

    SendEmailOnTillJob.run(id: id, address: address)

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
    cron = CronParser.new("0 */2 * * *")

    SendEmailOnForJob.run(id: id, address: address)

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
