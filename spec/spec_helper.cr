require "spec"

require "carbon"
require "timecop"

require "../src/spec"
require "./support/**"
require "../src/carbon"

include Carbon::Expectations

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
