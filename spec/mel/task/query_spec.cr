require "../../spec_helper"

describe Mel::Task::Query do
  describe ".truncate" do
    it "deletes all tasks" do
      address = "user@domain.tld"

      SendEmailJob.run(address: address)
      SendEmailJob.run_every(1.hour, address: address)
      SendEmailJob.run_on("0 2 * * *", address: address)

      Mel::Task.find(-1).try(&.size).should eq(3)
      Mel::Task::Query.truncate
      Mel::Task.find(-1).should be_nil
    end

    it "does not delete non-task data" do
      address = "user@domain.tld"
      not_mel_keys = ["not_mel", "#{Mel::Progress::Query.key}:2", "not_mel_3"]
      not_mel_all = not_mel_keys.zip(not_mel_keys).flat_map(&.to_a)

      SendEmailJob.run(address: address)
      Mel::Task.find(-1).try(&.size).should eq(1)

      Mel.redis.run(["MSET"] + not_mel_all)
      Mel.redis.mget(not_mel_keys).as(Array).size.should eq(3)

      Mel::Task::Query.truncate

      Mel::Task.find(-1).should be_nil
      Mel.redis.mget(not_mel_keys).as(Array).should_not contain(nil)

      # Clean up
      Mel.redis.del(not_mel_keys)
    end
  end
end
