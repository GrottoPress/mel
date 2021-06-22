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
    class_property worker_id : Int32?
  end

  private enum State
    Ready
    Started
    Stopping
    Stopped
  end

  class_getter state = State::Ready

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

  def start
    return log_already_started if state.started?

    log_starting
    handle_signal

    run_pending_tasks(pond = Pond.new)
    run_tasks(pond)
  end

  def stop
    return log_not_started unless state.started?

    log_stopping
    @@state = State::Stopping unless state.stopped?

    until state.stopped?
      Fiber.yield
    end
  end

  private def run_pending_tasks(pond)
    Task.find_pending.try do |tasks|
      tasks.each &.run(force: true).try { |fiber| pond << fiber }
    end
  end

  private def run_tasks(pond)
    log_started
    @@state = State::Started

    while state.started?
      Task.find_lte(Time.local, batch_size(pond), delete: nil).try do |tasks|
        tasks.each &.run(force: true).try { |fiber| pond << fiber }
      end

      sleep settings.poll_interval
    end

    log_waiting
    pond.drain

    log_stopped
    @@state = State::Stopped
  end

  private def handle_signal
    {Signal::INT, Signal::TERM}.each &.trap { stop }
  end

  private def batch_size(pond)
    return settings.batch_size if settings.batch_size > -2
    {0, settings.batch_size.abs - pond.size}.max
  end
end
