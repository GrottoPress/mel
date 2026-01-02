require "./mel"
require "./spec/**"

module Mel
  def start_and_stop(count : Int = 1)
    count.times { start_async {} }
  end

  def sync(task : Task?)
    Pond.drain { |pond| task.try &.run(pond) }
  end
end
