Mel.configure do |settings|
  settings.poll_interval = 1.millisecond
  settings.redis_url = ENV["REDIS_URL"]
  settings.batch_size = -1
  settings.timezone = Time::Location.load("America/Los_Angeles")
end
