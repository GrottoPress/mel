require "./task"

module Mel
  class InstantTask < Task
    private def schedule_next
      dequeue
    end
  end
end
