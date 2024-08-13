Mel.configure do |settings|
  settings.batch_size = -1
  settings.poll_interval = 10.milliseconds
  settings.timezone = Time::Location.load("America/Los_Angeles")
end

tasks = ->do
  Mel.stop
  Mel.settings.store.try(&.truncate)
  Mel.settings.store.try(&.truncate_progress)
end

Spec.around_each do |spec|
  next spec.run if all_tags(spec.example).includes?("skip_around_each")

  {Mel::Memory.new, Mel::Redis.new(ENV["REDIS_URL"])}.each do |store|
    Mel.settings.store = store
    tasks.call
    spec.run
  end
end

Spec.after_suite(&tasks)

private def all_tags(example)
  return Set(String).new unless example.is_a?(Spec::Item)
  result = example.tags.try(&.dup) || Set(String).new
  result + all_tags(example.parent)
end
