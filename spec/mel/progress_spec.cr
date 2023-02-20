require "../spec_helper"

describe Mel::Progress do
  describe ".new" do
    it "does not save progress to redis" do
      progress_id = "some_job_1"

      Mel::Progress.new(progress_id, "Some job description")
      Mel::Progress.track(progress_id).should be_nil
    end
  end

  describe ".start" do
    it "saves progress to redis" do
      progress_id = "some_job_1"

      Mel::Progress.start(progress_id, "Some job description")
      Mel::Progress.track(progress_id).try(&.started?).should be_true
    end
  end

  describe "#track" do
    it "tracks progress" do
      ProgressJob.run(retries: 0)

      Mel.settings.worker_id = 4

      Mel.start_and_stop

      report = Mel::Progress.track(ProgressJob.progress_id)
      report.should_not be_nil

      report.try do |_report|
        _report.value.should eq(50)
        _report.description.should eq(ProgressJob.progress_description)
        _report.moving?.should be_true
      end

      Mel.start_and_stop

      report = Mel::Progress.track(ProgressJob.progress_id)
      report.should_not be_nil

      report.try do |_report|
        _report.value.should eq(80)
        _report.moving?.should be_true
      end

      Mel.start_and_stop

      report = Mel::Progress.track(ProgressJob.progress_id)
      report.should_not be_nil

      report.try do |_report|
        _report.success?.should be_false
        _report.failure?.should be_true
      end
    end
  end

  describe "#move" do
    it "moves progress" do
      progress_id = "some_job_1"
      progress = Mel::Progress.start(progress_id, "Some job description")

      progress.move(70)
      Mel::Progress.track(progress_id).try(&.value).should eq(70)

      progress.move(40)
      Mel::Progress.track(progress_id).try(&.value).should eq(40)
    end

    it "ensures progress never exceeds 100%" do
      progress_id = "some_job_2"
      progress = Mel::Progress.start(progress_id, "Some job description")

      progress.move(120)
      Mel::Progress.track(progress_id).try(&.value).should eq(100)
    end

    it "fails progress if less than 0%" do
      progress_id = "some_job_3"
      progress = Mel::Progress.start(progress_id, "Some job description")

      progress.move(-120)

      report = Mel::Progress.track(progress_id)
      report.should_not be_nil

      report.try do |_report|
        _report.value.should eq(-1)
        _report.failure?.should be_true
      end
    end
  end
end
