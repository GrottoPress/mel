require "./spec_helper"

describe Mel do
  describe ".run" do
    it "runs tasks" do
      address = "user@domain.tld"

      CollectJobsJob.run
      CollectJobsJob.run_every(2.hours, for: 4.hours)

      JOBS.size.should eq(0)

      Mel.settings.poll_interval = 1.millisecond

      pond = Pond.new

      pond.fill { Mel.start }
      Mel.state.ready?.should be_true

      sleep 2.milliseconds
      Mel.state.started?.should be_true

      Timecop.travel(2.hours.from_now) do
        sleep 2.milliseconds
        Process.signal(Signal::INT, Process.pid)

        pond.drain
        Mel.state.stopped?.should be_true
      end

      JOBS.size.should eq(2)
    end
  end
end
