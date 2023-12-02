require "../../spec_helper"

describe Mel::Task::LogHelpers do
  it "logs successful instant task" do
    id = "1"

    Log.capture(Mel.log.source) do |logs|
      SendEmailJob.run(id: id, address: "aa@bb.cc", retries: 1)

      Mel.sync Mel::InstantTask.find(id, delete: true)

      logs.check(:info, /Enqueueing task/)
      logs.check(:info, /Task enqueued/)
      logs.check(:info, /Running task/)
      logs.check(:info, /Task completed/)
      logs.check(:info, /Dequeueing task/)
      logs.check(:info, /Task dequeued/)
    end
  end

  it "logs failed instant task" do
    id = "1"

    Log.capture(Mel.log.source) do |logs|
      FailedJob.run(id: id, retries: 1)

      Mel.sync Mel::InstantTask.find(id)
      Mel.sync Mel::InstantTask.find(id, delete: true)

      logs.check(:info, /Enqueueing task/)
      logs.check(:info, /Task enqueued/)
      logs.check(:info, /Running task/)
      logs.check(:warn, /Task errored/)
      logs.check(:info, /Enqueueing task/)
      logs.check(:info, /Task enqueued/)
      logs.check(:info, /Running task/)
      logs.check(:warn, /Task errored/)
      logs.check(:error, /Task failed/)
      logs.check(:info, /Dequeueing task/)
      logs.check(:info, /Task dequeued/)
    end
  end

  it "logs successful recurring task" do
    id = "1"

    Log.capture(Mel.log.source) do |logs|
      SendEmailJob.run_every(1.hour, id: id, address: "aa@bb.cc", retries: 1)

      Timecop.travel(1.hour.from_now) do
        Mel.sync Mel::PeriodicTask.find(id, delete: true)
      end

      logs.check(:info, /Enqueueing task/)
      logs.check(:info, /Task enqueued/)
      logs.check(:info, /Running task/)
      logs.check(:info, /Task completed/)
      logs.check(:info, /Recheduling recurring task/)
      logs.check(:info, /Recurring task rescheduled/)
    end
  end

  it "logs failed recurring task" do
    id = "1"

    Log.capture(Mel.log.source) do |logs|
      FailedJob.run_every(1.hour, id: id, retries: 1)

      Timecop.travel(1.hour.from_now) do
        Mel.sync Mel::PeriodicTask.find(id)
        Mel.sync Mel::PeriodicTask.find(id, delete: true)
      end

      logs.check(:info, /Enqueueing task/)
      logs.check(:info, /Task enqueued/)
      logs.check(:info, /Running task/)
      logs.check(:warn, /Task errored/)
      logs.check(:info, /Enqueueing task/)
      logs.check(:info, /Task enqueued/)
      logs.check(:info, /Running task/)
      logs.check(:warn, /Task errored/)
      logs.check(:error, /Task failed/)
      logs.check(:info, /Recheduling recurring task/)
      logs.check(:info, /Recurring task rescheduled/)
    end
  end
end
