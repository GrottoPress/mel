require "./mel"
require "./worker/**"

module Mel
  private module Settings
    class_property batch_size : Int32 = -100
    class_property poll_interval : Time::Span = 15.seconds

    class_setter worker_id : Int32?

    def self.worker_id : Int32
      @@worker_id ||= ENV["WORKER_ID"].to_i
    end
  end

  enum State
    Ready
    Started
    Stopping
    Stopped
  end

  @@mutex = Mutex.new

  class_getter state = State::Ready

  def start_async
    start_async
    yield
    stop
  end

  def start_async
    spawn { start }

    until state.started?
      Fiber.yield
    end
  end

  def start
    return log_already_started if state.started?

    log_starting
    run_handlers

    run_pending_tasks(pond = Pond.new)
    run_tasks(pond)
  end

  def stop
    return log_not_started unless state.started?

    log_stopping
    sync { @@state = State::Stopping } unless state.stopped?

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
    sync { @@state = State::Started }

    while state.started?
      Task.find_lte(Time.local, batch_size(pond), delete: nil).try do |tasks|
        tasks.each &.run(force: true).try { |fiber| pond << fiber }
      end

      sleep jittered_poll_interval
    end

    log_waiting
    pond.drain

    log_stopped
    sync { @@state = State::Stopped }
  end

  private def run_handlers
    at_exit { stop }

    {Signal::INT, Signal::TERM}.each &.trap { stop }
  end

  private def batch_size(pond)
    return settings.batch_size if settings.batch_size > -2
    {0, settings.batch_size.abs - pond.size}.max
  end

  private def sync
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
