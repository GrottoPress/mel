require "./spec_helper"

describe Mel do
  it "runs tasks" do
    address = "user@domain.tld"

    CollectJobsJob.run
    CollectJobsJob.run_every(2.hours, for: 4.hours)

    JOBS.lazy_get.should eq(0)

    Timecop.travel(2.hours.from_now) do
      Mel.start_and_stop
      Mel.state.stopped?.should be_true
      JOBS.lazy_get.should eq(2)
    end
  end

  it "stops on SIGINT" do
    Mel.start_async
    Process.signal(Signal::INT, Process.pid)

    10_000.times do
      break if Mel.state.stopped?
      Fiber.yield
    end

    Mel.state.stopped?.should be_true
  end

  it "stops on SIGTERM" do
    Mel.start_async
    Process.signal(Signal::TERM, Process.pid)

    10_000.times do
      break if Mel.state.stopped?
      Fiber.yield
    end

    Mel.state.stopped?.should be_true
  end
end
