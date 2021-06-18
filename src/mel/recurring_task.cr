require "./task"

module Mel::RecurringTask
  macro included
    include Mel::Task

    property till : Time?

    private def schedule_next
      return dequeue if till.try(&.< next_time)
      log_scheduling

      task = clone
      task.time = next_time
      task.enqueue(force: true)

      log_scheduled
    end

    private def next_time : Time
    end
  end
end
