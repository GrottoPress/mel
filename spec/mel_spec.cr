require "./spec_helper"

describe Mel do
  it "runs tasks" do
    address = "user@domain.tld"

    CollectJobsJob.run
    CollectJobsJob.run_every(2.hours, for: 4.hours)

    JOBS.lazy_get.should eq(0)

    Timecop.travel(2.hours.from_now) do
      Mel.start_and_stop
      Mel.state.ended?.should be_true
      JOBS.lazy_get.should eq(2)
    end
  end

  it "stops on SIGINT" do
    Mel.start_async
    Process.signal(Signal::INT, Process.pid)

    sleep 2.milliseconds
    Mel.state.started?.should be_false
  end

  it "stops on SIGTERM" do
    Mel.start_async
    Process.signal(Signal::TERM, Process.pid)

    sleep 2.milliseconds
    Mel.state.started?.should be_false
  end
end
