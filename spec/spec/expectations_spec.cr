require "../spec_helper"

describe Mel::BeEnqueuedExpectation do
  describe "#be_enqueued" do
    context "in positive assertions" do
      it "passes if job is enqueued" do
        SendEmailJob.run(address: "user@domain.tld")

        SendEmailJob.should be_enqueued
      end

      it "passes if type matches" do
        SendEmailJob.run_every(1.hour, address: "newuser@domain.tld")

        SendEmailJob.should be_enqueued(as: Mel::PeriodicTask)
        SendEmailJob.should be_enqueued(as: Mel::RecurringTask)
      end

      it "passes if count matches" do
        SendEmailJob.run(address: "user@domain.tld")
        SendEmailJob.run_every(1.hour, address: "newuser@domain.tld")

        SendEmailJob.should be_enqueued(2)
      end

      it "passes if ID matches" do
        id = "1001"
        SendEmailJob.run(id: id, address: "user@domain.tld")

        SendEmailJob.should be_enqueued(id)
      end

      it "passes if both count and type match" do
        SendEmailJob.run(address: "user@domain.tld")
        SendEmailJob.run_every(1.hour, address: "newuser@domain.tld")

        SendEmailJob.should be_enqueued(1, as: Mel::PeriodicTask)
        SendEmailJob.should be_enqueued(1, as: Mel::RecurringTask)
      end

      it "passes if ID and type match" do
        id = "1001"
        SendEmailJob.run_every(1.hour, id: id, address: "newuser@domain.tld")

        SendEmailJob.should be_enqueued(id, as: Mel::PeriodicTask)
      end

      it "fails if job is not enqueued" do
        expect_raises Spec::AssertionFailed, " be enqueued" do
          SendEmailJob.should be_enqueued
        end
      end

      it "fails if type does not match" do
        SendEmailJob.run(address: "user@domain.tld")

        SendEmailJob.should be_enqueued

        expect_raises Spec::AssertionFailed, " be enqueued as " do
          SendEmailJob.should be_enqueued(as: Mel::RecurringTask)
        end
      end

      it "fails if count does not match" do
        SendEmailJob.run(address: "user@domain.tld")

        SendEmailJob.should be_enqueued

        expect_raises Spec::AssertionFailed, " be enqueued exactly 4 times" do
          SendEmailJob.should be_enqueued(4)
        end
      end

      it "fails if ID does not match" do
        SendEmailJob.run(address: "user@domain.tld")

        expect_raises Spec::AssertionFailed, " be enqueued" do
          SendEmailJob.should be_enqueued("1002")
        end
      end

      it "fails if both count and type do not match" do
        SendEmailJob.run(address: "user@domain.tld")

        SendEmailJob.should be_enqueued

        expect_raises Spec::AssertionFailed, " exactly 2 times as " do
          SendEmailJob.should be_enqueued(2, Mel::CronTask)
        end
      end

      it "fails if both ID and type do not match" do
        SendEmailJob.run(address: "user@domain.tld")

        SendEmailJob.should be_enqueued

        expect_raises Spec::AssertionFailed, " be enqueued as " do
          SendEmailJob.should be_enqueued("1002", Mel::CronTask)
        end
      end
    end

    context "in negative assertions" do
      it "passes if job is not enqueued" do
        SendEmailJob.should_not be_enqueued
      end

      it "passes if type does not match" do
        SendEmailJob.run(address: "user@domain.tld")

        SendEmailJob.should be_enqueued
        SendEmailJob.should_not be_enqueued(as: Mel::CronTask)
      end

      it "passes if count does not match" do
        SendEmailJob.run(address: "user@domain.tld")

        SendEmailJob.should be_enqueued
        SendEmailJob.should_not be_enqueued(4)
      end

      it "passes if ID does not match" do
        SendEmailJob.run(address: "user@domain.tld")

        SendEmailJob.should_not be_enqueued("1002")
      end

      it "passes if both count and type do not match" do
        SendEmailJob.run(address: "user@domain.tld")

        SendEmailJob.should be_enqueued
        SendEmailJob.should_not be_enqueued(3, as: Mel::CronTask)
      end

      it "passes if both ID and type do not match" do
        SendEmailJob.run(address: "user@domain.tld")

        SendEmailJob.should be_enqueued
        SendEmailJob.should_not be_enqueued("1002", as: Mel::CronTask)
      end

      it "fails if job is enqueued" do
        SendEmailJob.run(address: "user@domain.tld")

        expect_raises Spec::AssertionFailed, " not be enqueued" do
          SendEmailJob.should_not be_enqueued
        end
      end

      it "fails if type matches" do
        SendEmailJob.run_every(1.hour, address: "newuser@domain.tld")

        expect_raises Spec::AssertionFailed, " not be enqueued as " do
          SendEmailJob.should_not be_enqueued(as: Mel::PeriodicTask)
        end

        expect_raises Spec::AssertionFailed, " not be enqueued as " do
          SendEmailJob.should_not be_enqueued(as: Mel::RecurringTask)
        end
      end

      it "fails if count matches" do
        SendEmailJob.run(address: "user@domain.tld")
        SendEmailJob.run_every(1.hour, address: "newuser@domain.tld")

        expect_raises Spec::AssertionFailed, " not be enqueued exactly 2 " do
          SendEmailJob.should_not be_enqueued(2)
        end
      end

      it "fails if ID matches" do
        id = "1001"
        SendEmailJob.run(id: id, address: "user@domain.tld")

        expect_raises Spec::AssertionFailed, " not be enqueued" do
          SendEmailJob.should_not be_enqueued(id)
        end
      end

      it "fails if both count and type match" do
        SendEmailJob.run(address: "user@domain.tld")
        SendEmailJob.run_every(1.hour, address: "newuser@domain.tld")

        SendEmailJob.should be_enqueued(1, as: Mel::PeriodicTask)
        SendEmailJob.should be_enqueued(1, as: Mel::RecurringTask)

        expect_raises(
          Spec::AssertionFailed,
          " not be enqueued exactly once as "
        ) do
          SendEmailJob.should_not be_enqueued(1, as: Mel::PeriodicTask)
        end

        expect_raises(
          Spec::AssertionFailed,
          " not be enqueued exactly once as "
        ) do
          SendEmailJob.should_not be_enqueued(1, as: Mel::RecurringTask)
        end
      end

      it "fails if both ID and type match" do
        id = "1001"
        SendEmailJob.run_every(1.hour, id: id, address: "newuser@domain.tld")

        expect_raises Spec::AssertionFailed, " not be enqueued as " do
          SendEmailJob.should_not be_enqueued(id, as: Mel::PeriodicTask)
        end
      end
    end
  end
end
