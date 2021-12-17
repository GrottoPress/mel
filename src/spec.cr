require "./worker"

module Mel
  def start_and_stop(count : Int)
    count.times { start_and_stop }
  end

  def start_and_stop
    spawn do
      until state.started?
        Fiber.yield
      end

      stop
    end

    start
  end

  def start_async
    spawn { start }

    until state.started?
      Fiber.yield
    end
  end

  def sync(task : Task?)
    task.try &.run.try { |fiber| Pond.drain(fiber) }
  end
end
