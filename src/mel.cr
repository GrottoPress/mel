require "json"
require "uri"
require "uuid"

require "cron_parser"
require "pond"

require "./mel/version"
require "./mel/helpers"
require "./mel/**"

module Mel
  enum State
    Ready
    Started
    Stopping
    Stopped
  end

  private module Settings
    class_property batch_size : Int32 = -100
    class_property error_handler : Exception -> = ->(__ : Exception) { }
    class_property poll_interval : Time::Span = 3.seconds
    class_property progress_expiry : Time::Span? = 1.day
    class_property store : Store?
    class_property timezone : Time::Location?
  end

  extend self

  include LogHelpers

  @@mutex = Mutex.new

  class_getter state = State::Ready

  def settings
    Settings
  end

  def configure(&) : Nil
    yield settings

    settings.timezone.try { |location| Time::Location.local = location }
  end

  def log
    Log.for(self)
  end

  def start_async(&)
    start_async
    yield
    stop
  end

  def start_async
    spawn { start }

    until state.started?
      sleep 1.microsecond
    end
  end

  def start
    return log_already_started if state.started?

    log_starting
    run_handlers

    RunPool.delete
    run_tasks(Pond.new)
  end

  def stop
    return log_not_started unless state.started?

    log_stopping
    lock { @@state = State::Stopping } unless state.stopped?

    until state.stopped?
      sleep 1.microsecond
    end
  end

  def transaction(& : Transaction -> _)
    settings.store.try &.transaction { |transaction| yield transaction }
  end

  private def run_tasks(pond)
    log_started
    lock { @@state = State::Started }

    while state.started?
      Task.find_due(Time.local, batch_size(pond), delete: nil).try do |tasks|
        tasks.each &.run(pond, force: true)
      end

      sleep jittered_poll_interval
    end

    log_waiting
    pond.drain

    log_stopped
    lock { @@state = State::Stopped }
  end

  private def run_handlers
    at_exit { stop }

    {Signal::INT, Signal::TERM}.each &.trap { stop }
  end

  private def batch_size(pond)
    return settings.batch_size if settings.batch_size > -2
    {0, settings.batch_size.abs - pond.size}.max
  end

  private def lock(&)
    @@mutex.synchronize { yield }
  end

  private def jittered_poll_interval
    interval = settings.poll_interval.total_milliseconds
    delta = interval / 3
    min = interval - delta
    max = interval + delta

    Random.rand(min..max).milliseconds
  end
end
