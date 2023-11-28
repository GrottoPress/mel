require "./task/**"

abstract class Mel::Task
  macro inherited
    def self.find_pending(count = -1, *, delete = false) : Array(self)?
      return if count.zero?

      Mel::Task.find_pending(-1, delete: false).try do |tasks|
        tasks = resize(tasks.select(self), count)
        return if tasks.empty?
        delete(tasks, delete).try &.map(&.as self)
      end
    end
  end

  def self.find_pending(count = -1, *, delete = false)
    Query.find_pending(count, delete: delete).try { |values| from_json(values) }
  end
end
