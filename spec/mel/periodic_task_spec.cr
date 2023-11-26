require "../spec_helper"

describe Mel::PeriodicTask do
  describe ".find" do
    it "returns all periodic tasks" do
      address = "user@domain.tld"

      SendEmailJob.run(address: address)
      SendEmailJob.run_in(2.hours, address: address)
      SendEmailJob.run_at(4.hours.from_now, address: address)
      SendEmailJob.run_every(1.hour, address: address)
      SendEmailJob.run_on("0 2 * * *", address: address)

      Mel::PeriodicTask.find(-1).try(&.size).should eq(1)
      Mel::RecurringTask.find(-1).try(&.size).should eq(2)
    end
  end
end
