require "json"
require "uri"
require "uuid"

require "cron_parser"
require "redis"
require "pond"

require "./mel/version"
require "./mel/**"

module Mel
  extend self

  include LogHelpers

  private module Settings
    class_property progress_expiry : Time::Span? = 1.day
    class_property! redis_url : String
    class_property redis_pool_size : Int32?
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
    @@redis ||= begin
      uri = URI.parse(settings.redis_url)

      settings.redis_pool_size.try do |size|
        uri.query_params["max_idle_pool_size"] = size.to_s
      end

      Redis::Client.new(uri)
    end
  end
end
