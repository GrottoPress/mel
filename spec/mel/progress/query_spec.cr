require "../../spec_helper"

describe Mel::Progress::Query do
  describe ".truncate" do
    it "deletes all progress data" do
      progress_id = "some_job_11"
      progress = Mel::Progress.new(progress_id, "Some job description")

      progress.move(10)
      Mel::Progress.track(progress_id).try(&.value).should eq(10)

      Mel::Progress::Query.truncate
      Mel::Progress.track(progress_id).try(&.value).should be_nil
    end

    it "does not delete non-progress data" do
      not_mel_keys = ["#{Mel::Task::Query.key}:1", "not_mel_2"]
      not_mel_all = not_mel_keys.zip(not_mel_keys).flat_map(&.to_a)

      Mel.redis.run(["MSET"] + not_mel_all)
      Mel.redis.mget(not_mel_keys).as(Array).size.should eq(2)

      progress_id = "some_job_12"
      progress = Mel::Progress.new(progress_id, "Some job description")

      progress.move(10)
      Mel::Progress.track(progress_id).try(&.value).should eq(10)

      Mel::Progress::Query.truncate

      Mel::Progress.track(progress_id).try(&.value).should be_nil
      Mel.redis.mget(not_mel_keys).as(Array).should_not contain(nil)

      # Clean up
      Mel.redis.del(not_mel_keys)
    end
  end
end
