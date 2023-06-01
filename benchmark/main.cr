# 1. Build: `crystal build \
#          --release \
#          -D preview_mt \
#          -o melbench \
#          benchmark/main.cr`
#
# 2. Set env vars:
#    - BATCH_SIZE
#    - CRYSTAL_WORKERS
#    - ITERATIONS
#    - REDIS_URL
#    - WORKER_ID
#
# 3. Run: `./melbench`

require "benchmark"

require "../src/spec"

ITERATIONS = ENV["ITERATIONS"]?.try(&.to_i) || 100_000

Mel.configure do |settings|
  settings.batch_size = ENV["BATCH_SIZE"]?.try(&.to_i) || 10_000
  settings.poll_interval = 1.microsecond
  settings.redis_key_prefix = "melbench"
  settings.redis_url = ENV["REDIS_URL"]
  settings.worker_id = ENV["WORKER_ID"].to_i
end

Log.setup(Mel.log.source, :none)

struct DoNothing
  include Mel::Job::Now

  def run
  end
end

Benchmark.bm do |job|
  Mel::Task::Query.truncate

  job.report("Sequential schedule #{ITERATIONS} jobs") do
    ITERATIONS.times { DoNothing.run(retries: 0) }
  end

  Mel::Task::Query.truncate

  job.report("Bulk schedule #{ITERATIONS} jobs") do
    Mel.redis.multi do |redis|
      ITERATIONS.times { DoNothing.run(redis: redis, retries: 0) }
    end
  end

  batch_size = Mel.settings.batch_size
  batches = batch_size < 1 ? 1 : (ITERATIONS / batch_size).ceil.to_i

  job.report("Run #{ITERATIONS} scheduled jobs") { Mel.start_and_stop(batches) }

  Mel::Task::Query.truncate
end
