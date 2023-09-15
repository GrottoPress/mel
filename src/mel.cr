require "json"
require "uri"
require "uuid"

require "cron_parser"
require "redis"
require "pond"

require "./mel/version"
require "./mel/helpers"
require "./mel/**"

module Mel
  extend self

  include LogHelpers

  private module Settings
    class_property error_handler : Exception -> = ->(__ : Exception) { }
    class_property progress_expiry : Time::Span? = 1.day
    class_property! redis_url : String
    class_property redis_key_prefix : String = "mel"
    class_property timezone : Time::Location?
  end

  def settings
    Settings
  end

  def configure : Nil
    yield settings

    settings.timezone.try { |location| Time::Location.local = location }
  end

  def log
    @@log ||= Log.for(self)
  end

  def redis
    @@redis ||= Redis::Client.new(URI.parse settings.redis_url)
  end
end
