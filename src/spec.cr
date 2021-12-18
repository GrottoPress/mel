require "./worker"

module Mel
  def start_and_stop(count : Int = 1)
    count.times { start_async {} }
  end

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

  def sync(task : Task?)
    task.try &.run.try { |fiber| Pond.drain(fiber) }
  end
end
