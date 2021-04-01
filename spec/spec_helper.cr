require "spec"

require "timecop"

require "../src/mel"
require "./support/**"

Mel.configure do |config|
  config.redis_url = ENV["REDIS_URL"]
  config.batch_size = -1
end

Spec.before_each do
  Time::Location.local = Time::Location.load("America/Los_Angeles")
  Mel.redis.del(Mel::Task.key)

  keys = Mel.redis.keys("#{Mel::Task.key}*")
  Mel.redis.run(["DEL"] + keys) unless keys.empty?
end

def sync(task)
  task.try &.run.try { |fiber| Pond.drain(fiber) }
end
