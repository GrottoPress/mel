require "../spec_helper"

describe Mel::Progress do
  describe "#track" do
    it "tracks progress" do
      progress = Mel::Progress.new(ProgressJob.progress_id)

      ProgressJob.run(retries: 0)

      Mel.settings.worker_id = 4

      Mel.start_and_stop
      progress.track.should eq(50)
      progress.tracking?.should be_true

      Mel.start_and_stop
      progress.track.should eq(80)
      progress.tracking?.should be_true

      Mel.start_and_stop
      progress.success?.should be_false
      progress.failure?.should be_true
    end

    it "ensures progress never exceeds 100%" do
      progress = Mel::Progress.new(ProgressJob.progress_id)

      progress.track(120)
      progress.track.should eq(100)
    end

    it "fails progress if less than 0%" do
      progress = Mel::Progress.new(ProgressJob.progress_id)

      progress.track(-120)
      progress.track.should eq(-1)
      progress.failure?.should be_true
    end
  end
end
