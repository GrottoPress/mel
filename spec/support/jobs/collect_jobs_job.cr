JOBS = Array(String).new
private MUTEX = Mutex.new

struct CollectJobsJob
  include Mel::Job

  def run
    MUTEX.synchronize { JOBS << @__type__ }
  end
end
