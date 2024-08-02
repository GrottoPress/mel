require "./store"

module Mel
  # DO NOT USE IN PRODUCTION:
  #
  #   This is not very useful, unless the app and worker share memory.
  #   Besides, memory does not provide the persistence that Mel requires.
  #
  #   You may use this for tests or demos.
  class Memory
    alias Progress = Hash(String, ProgressEntry)
    alias Queue = Hash(String, Int64)
    alias Tasks = Hash(String, String)

    include Store

    getter :mutex
    getter :progress
    getter :queue
    getter :tasks

    def initialize(
      @queue = Queue.new,
      @tasks = Tasks.new,
      @progress = Progress.new,
      @mutex = Mutex.new
    )
    end

    def sorted_queue : Queue
      queue.to_a.sort_by!(&.[1]).to_h
    end

    def find_due(
      at time = Time.local,
      count : Int = -1, *,
      delete : Bool? = false
    ) : Array(String)?
      return if count.zero?

      query = ->do
        queue = sorted_queue.select { |_, value| 0 <= value <= time.to_unix }
        count(queue, count).keys
      end

      if delete.nil?
        ids = lock do query.call.tap { |_ids| to_pending(_ids) } end
        return find(ids, delete: false)
      end

      ids = lock { query.call }
      find(ids, delete: delete)
    end

    def find_pending(count : Int, *, delete : Bool = false) : Array(String)?
      return if count.zero?

      queue = self.queue.select { |_, value| value == worker_score }
      ids = count(queue, count).keys

      find(ids, delete: delete)
    end

    def find(count : Int, *, delete : Bool? = false) : Array(String)?
      return if count.zero?

      query = ->do
        queue = sorted_queue.select { |_, value| value >= 0 }
        count(queue, count).keys
      end

      if delete.nil?
        ids = lock do query.call.tap { |_ids| to_pending(_ids) } end
        return find(ids, delete: false)
      end

      ids = lock { query.call }
      find(ids, delete: delete)
    end

    def find(ids : Indexable, *, delete : Bool = false) : Array(String)?
      return if ids.empty?

      values = lock do
        ids.compact_map do |id|
          @queue.delete(id) if delete
          delete ? @tasks.delete(id) : @tasks[id]?
        end
      end

      values unless values.empty?
    end

    def transaction(& : Transaction -> _)
      yield Transaction.new(queue, tasks, progress)
    end

    def truncate
      @queue.clear
      @tasks.clear
    end

    def get_progress(ids : Indexable) : Array(String)?
      return if ids.empty?

      values = lock do
        ids.compact_map do |id|
          @progress[id]?.try do |entry|
            next entry.value unless entry.expired?
            @progress.delete(id)
            nil
          end
        end
      end

      values unless values.empty?
    end

    def truncate_progress
      @progress.clear
    end

    private def count(queue, count)
      count < 0 ? queue.to_h : queue.first(count).to_h
    end

    private def lock
      @mutex.synchronize { yield }
    end

    private def to_pending(ids)
      ids.each { |id| queue[id] = worker_score }
    end

    private def worker_score
      -Mel.settings.worker_id.abs.to_i64
    end

    struct Transaction
      include Store::Transaction

      def initialize(@queue : Queue, @tasks : Tasks, @progress : Progress)
      end

      def create(task : Task)
        @queue[task.id] ||= task.time.to_unix
        @tasks[task.id] ||= task.to_json
      end

      def update(task : Task)
        time = task.retry_time || task.time

        @queue[task.id] = time.to_unix
        @tasks[task.id] = task.to_json
      end

      def set_progress(id : String, value : Int, description : String)
        report = Mel::Progress::Report.new(id, description, value)
        @progress[id] = ProgressEntry.new(report.to_json)
      end
    end

    struct ProgressEntry
      getter :value

      getter expire : Time?

      def initialize(@value : String)
        @expire = Mel.settings.progress_expiry.try(&.from_now)
      end

      def expired? : Bool
        !!expire.try { |expire| expire <= Time.local }
      end
    end
  end
end
