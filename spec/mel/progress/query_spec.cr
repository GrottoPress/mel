require "../../spec_helper"

describe Mel::Progress::Query do
  describe ".truncate" do
    it "deletes all progress data" do
      progress = Mel::Progress.new("some_job_11")
      progress.move(10)
      progress.track.should eq(10)

      Mel::Progress::Query.truncate
      progress.track.should eq(0)
    end

    it "does not delete non-progress data" do
      not_mel_keys = ["#{Mel::Task::Query.key}:1", "not_mel_2"]
      not_mel_all = not_mel_keys.zip(not_mel_keys).flat_map(&.to_a)

      Mel.redis.run(["MSET"] + not_mel_all)
      Mel.redis.mget(not_mel_keys).as(Array).size.should eq(2)

      progress = Mel::Progress.new("some_job_12")
      progress.move(10)
      progress.track.should eq(10)

      Mel::Progress::Query.truncate

      progress.track.should eq(0)
      Mel.redis.mget(not_mel_keys).as(Array).should_not contain(nil)

      # Clean up
      Mel.redis.run(["DEL"] + not_mel_keys)
    end
  end
end
