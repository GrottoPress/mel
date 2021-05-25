JOBS = Atomic(Int32).new(0)

struct CollectJobsJob
  include Mel::Job

  def run
    JOBS.add(1)
  end
end
