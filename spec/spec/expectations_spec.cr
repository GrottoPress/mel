require "../spec_helper"

describe Mel::BeEnqueuedExpectation do
  describe "#be_enqueued" do
    context "in positive assertions" do
      it "passes if job is enqueued" do
        SendEmailJob.run(address: "user@domain.tld")

        SendEmailJob.should be_enqueued
        SendEmailJob.should be_enqueued(as: Mel::InstantTask)
      end

      it "fails if job is not enqueued" do
        expect_raises Spec::AssertionFailed, "to be enqueued" do
          SendEmailJob.should be_enqueued
        end

        expect_raises Spec::AssertionFailed, "to be enqueued as " do
          SendEmailJob.should be_enqueued(as: Mel::InstantTask)
        end
      end

      it "fails if expected type does not match" do
        SendEmailJob.run(address: "user@domain.tld")

        SendEmailJob.should be_enqueued

        expect_raises Spec::AssertionFailed, "to be enqueued as " do
          SendEmailJob.should be_enqueued(as: Mel::RecurringTask)
        end
      end
    end

    context "in negative assertions" do
      it "passes if job is not enqueued" do
        SendEmailJob.should_not be_enqueued
        SendEmailJob.should_not be_enqueued(as: Mel::InstantTask)
      end

      it "fails if job is enqueued" do
        SendEmailJob.run(address: "user@domain.tld")

        expect_raises Spec::AssertionFailed, "to not be enqueued" do
          SendEmailJob.should_not be_enqueued
        end

        expect_raises Spec::AssertionFailed, "to not be enqueued as " do
          SendEmailJob.should_not be_enqueued(as: Mel::InstantTask)
        end
      end

      it "passes if expected type does not match" do
        SendEmailJob.run(address: "user@domain.tld")

        SendEmailJob.should be_enqueued(as: Mel::InstantTask)
        SendEmailJob.should_not be_enqueued(as: Mel::CronTask)
      end
    end
  end
end
