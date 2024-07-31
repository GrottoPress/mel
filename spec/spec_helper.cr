require "spec"
require "log/spec"

require "carbon"
require "timecop"

require "../src/spec"
require "./setup/**"
require "./support/**"
require "../src/carbon"
require "../src/redis"

include Carbon::Expectations
