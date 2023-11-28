require "./task"

module Mel
  abstract class RecurringTask < Task
    getter till : Time?
    protected setter till : Time?
  end
end
