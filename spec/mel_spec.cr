require "./spec_helper"

describe Mel do
  it "runs tasks" do
    address = "user@domain.tld"

    CollectJobsJob.run
    CollectJobsJob.run_every(2.hours, for: 4.hours)

    JOBS.size.should eq(0)

    Mel.settings.poll_interval = 1.millisecond

    spawn { Mel.start }
    Mel.state.ready?.should be_true

    sleep 2.milliseconds
    Mel.state.started?.should be_true

    Timecop.travel(2.hours.from_now) do
      sleep 2.milliseconds
      Mel.stop
      Mel.state.ended?.should be_true
    end

    JOBS.size.should eq(2)
  end
end
