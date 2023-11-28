require "./task"

module Mel
  abstract class RecurringTask < Task
    private def next_retry_time
      super.try do |time|
        # Allow retry if task will not be rescheduled
        return time if till.try(&.< next_time)
        # Disallow retry beyond next schedule if task will be reschedduled
        time if time < next_time
      end
    end

    private def schedule_next
      return if till.try(&.< next_time)
      log_scheduling

      task = clone
      task.time = next_time
      task.enqueue(force: true)

      log_scheduled
    end

    private abstract def next_time : Time
  end
end
