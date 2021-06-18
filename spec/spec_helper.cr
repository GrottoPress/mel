require "spec"

require "carbon"
require "timecop"

require "../src/spec"
require "./support/**"
require "../src/carbon"

include Carbon::Expectations

Mel.configure do |settings|
  settings.poll_interval = 1.millisecond
  settings.redis_url = ENV["REDIS_URL"]
  settings.batch_size = -1
  settings.worker_id = 1
end

Spec.before_each do
  Time::Location.local = Time::Location.load("America/Los_Angeles")
  Mel::Task::Query.truncate
end

Spec.after_suite { Mel::Task::Query.truncate }
