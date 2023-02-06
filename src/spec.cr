require "./worker"

module Mel
  def start_and_stop(count : Int = 1)
    count.times { start_async {} }
  end

  def sync(task : Task?)
    task.try &.run.try { |fiber| Pond.drain(fiber) }
  end
end
