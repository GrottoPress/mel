Mel.configure do |settings|
  settings.batch_size = -1
  settings.poll_interval = 10.milliseconds
  settings.redis_url = ENV["REDIS_URL"]
  settings.timezone = Time::Location.load("America/Los_Angeles")
end
