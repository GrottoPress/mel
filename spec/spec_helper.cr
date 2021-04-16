require "spec"

require "timecop"

require "../src/mel"
require "./support/**"

Mel.configure do |settings|
  settings.redis_url = ENV["REDIS_URL"]
  settings.batch_size = -1
end

Spec.before_each do
  Time::Location.local = Time::Location.load("America/Los_Angeles")
  Mel::Task::Query.truncate
end

Spec.after_suite { Mel::Task::Query.truncate }

def sync(task)
  task.try &.run.try { |fiber| Pond.drain(fiber) }
end
