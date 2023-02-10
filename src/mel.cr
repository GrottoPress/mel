require "json"
require "uri"
require "uuid"

require "habitat"
require "cron_parser"
require "redis"
require "pond"

require "./mel/version"
require "./mel/helpers"
require "./mel/**"

module Mel
  extend self

  include LogHelpers

  Habitat.create do
    setting error_handler : Exception -> = ->(__ : Exception) { }
    setting progress_expiry : Time::Span? = 1.day
    setting redis_url : String
    setting redis_pool_size : Int32?
    setting redis_key_prefix : String = "mel"
    setting rescue_errors : Bool = true
    setting timezone : Time::Location?
  end

  def configure : Nil
    previous_def { yield }

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
