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
require "../src/redis"

ITERATIONS = ENV["ITERATIONS"]?.try(&.to_i) || 100_000

Mel.configure do |settings|
  settings.batch_size = ENV["BATCH_SIZE"]?.try(&.to_i) || 10_000
  settings.poll_interval = 1.microsecond
  settings.store = Mel::Redis.new(ENV["REDIS_URL"], "melbench")
end

Log.setup(Mel.log.source, :none)

struct DoNothing
  include Mel::Job::Now

  def run
  end
end

Benchmark.bm do |job|
  Mel.settings.store.try(&.truncate)

  job.report("Sequential schedule #{ITERATIONS} jobs") do
    ITERATIONS.times { DoNothing.run(retries: 0) }
  end

  Mel.settings.store.try(&.truncate)

  job.report("Bulk schedule #{ITERATIONS} jobs") do
    Mel.transaction do |store|
      ITERATIONS.times { DoNothing.run(store: store, retries: 0) }
    end
  end

  batch_size = Mel.settings.batch_size
  batches = batch_size < 1 ? 1 : (ITERATIONS / batch_size).ceil.to_i

  job.report("Run #{ITERATIONS} scheduled jobs") { Mel.start_and_stop(batches) }

  Mel.settings.store.try(&.truncate)
end
