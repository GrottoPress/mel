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
  settings.timezone = Time::Location.load("America/Los_Angeles")
end

Spec.before_each do
  Mel.stop
  Mel::Task::Query.truncate
  Mel::Progress::Query.truncate
end

Spec.after_suite do
  Mel.stop
  Mel::Task::Query.truncate
  Mel::Progress::Query.truncate
end

# Habitat.raise_if_missing_settings!
