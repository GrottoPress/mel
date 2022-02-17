require "./spec_helper"

describe Mel do
  it "runs tasks" do
    CollectJobsJob.run
    CollectJobsJob.run_every(2.hours, for: 4.hours)

    JOBS.lazy_get.should eq(0)

    Mel.settings.worker_id = 1

    Timecop.travel(2.hours.from_now) do
      Mel.start_and_stop
      Mel.state.stopped?.should be_true
      JOBS.lazy_get.should eq(2)
    end
  end

  it "stops on SIGINT" do
    Mel.settings.worker_id = 2

    Mel.start_async do
      Process.signal(Signal::INT, Process.pid)

      100_000.times do
        break if Mel.state.stopped?
        Fiber.yield
      end

      Mel.state.stopped?.should be_true
    end
  end

  it "stops on SIGTERM" do
    Mel.settings.worker_id = 3

    Mel.start_async do
      Process.signal(Signal::TERM, Process.pid)

      100_000.times do
        break if Mel.state.stopped?
        Fiber.yield
      end

      Mel.state.stopped?.should be_true
    end
  end
end
