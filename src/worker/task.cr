require "./task/**"

module Mel::Task
  macro included
    def self.find_pending(count = -1, *, delete = false) : Array(self)?
      return if count.zero?

      Mel::Task.find_pending(-1, delete: false).try do |tasks|
        tasks = Mel::Task.resize(tasks.select(self), count)
        return if tasks.empty?
        Mel::Task.delete(tasks, delete).try &.map(&.as self)
      end
    end
  end

  def find_pending(count = -1, *, delete = false)
    Query.find_pending(count, delete: delete).try { |values| from_json(values) }
  end
end
