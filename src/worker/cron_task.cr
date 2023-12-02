require "./recurring_task"

module Mel
  class CronTask < RecurringTask
    private def next_time : Time
      CronParser.new(schedule).next(time.to_local)
    end
  end
end
