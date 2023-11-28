require "./recurring_task"

module Mel
  class PeriodicTask < RecurringTask
    private def next_time : Time
      time + interval
    end
  end
end
