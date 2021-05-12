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
    class_property batch_size : Int32 = 10
    class_property poll_interval : Time::Span = 3.seconds
    class_property! redis_url : String
    class_property redis_pool_size : Int32?
    class_property timezone : Time::Location?
  end

  private enum State
    Ready
    Started
    Stopped
    Ended
  end

  class_getter state = State::Ready

  def settings
    Settings
  end

  def configure
    yield settings
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

  def start
    return log_already_started if state.started?

    configure
    log_starting
    @@state = State::Started

    handle_signal
    run_tasks
  end

  def stop
    return log_not_started unless state.started?
    log_stopping

    @@state = State::Stopped

    until state.ended?
      Fiber.yield
    end
  end

  private def configure
    settings.timezone.try { |location| Time::Location.local = location }
  end

  private def run_tasks
    log_started
    pond = Pond.new

    while state.started?
      Task.find_lte(
        Time.local,
        settings.batch_size,
        delete: true
      ).try do |tasks|
        tasks.each &.run(force: true).try { |fiber| pond << fiber }
      end

      sleep settings.poll_interval
    end

    log_waiting
    pond.drain
    log_stopped

    @@state = State::Ended
  end

  private def handle_signal
    {Signal::INT, Signal::TERM}.each &.trap { stop }
  end
end
