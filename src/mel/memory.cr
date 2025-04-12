require "./store"

module Mel
  # DO NOT USE IN PRODUCTION:
  #
  #   This is not very useful, unless the app and worker share memory.
  #   Besides, memory does not provide the persistence that Mel requires.
  #
  #   You may use this for tests or demos.
  struct Memory
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

      if delete.nil?
        ids = lock do
          to_running(RunPool.fetch)
          to_running query(count, delete, time)
        end

        RunPool.update(ids)
        return find(ids, delete: false)
      end

      ids = lock { query(count, delete, time) }
      find(ids, delete: delete)
    end

    def find(count : Int, *, delete : Bool? = false) : Array(String)?
      return if count.zero?

      if delete.nil?
        ids = lock do
          to_running(RunPool.fetch)
          to_running query(count, delete)
        end

        RunPool.update(ids)
        return find(ids, delete: false)
      end

      ids = lock { query(count, delete) }
      find(ids, delete: delete)
    end

    def find(ids : Indexable, *, delete : Bool = false) : Array(String)?
      return if ids.empty?

      values = lock do
        ids.compact_map do |id|
          if delete
            @queue.delete(id)
            next @tasks.delete(id)
          end

          @tasks[id]?
        end
      end

      values unless values.empty?
    end

    def transaction(& : Transaction -> _)
      yield Transaction.new(self)
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

    private def query(count, delete, time = nil)
      queue = sorted_queue.select do |_, value|
        if delete.nil?
          next orphan_score <= value <= time.to_unix if time
          next value >= orphan_score
        end

        next 0 <= value <= time.to_unix if time
        value >= 0
      end

      count(queue, count).keys
    end

    private def count(queue, count)
      count < 0 ? queue.to_h : queue.first(count).to_h
    end

    private def lock
      @mutex.synchronize { yield }
    end

    private def to_running(ids)
      ids.each { |id| queue[id] = running_score }
      ids
    end

    private def orphan_score
      -orphan_after.ago.to_unix
    end

    private def running_score
      -Time.local.to_unix
    end

    struct Transaction
      include Mel::Transaction

      def initialize(@memory : Memory)
      end

      def create(task : Task)
        @memory.queue[task.id] ||= task.time.to_unix
        @memory.tasks[task.id] ||= task.to_json
      end

      def update(task : Task)
        time = task.retry_time || task.time

        @memory.queue[task.id] = time.to_unix
        @memory.tasks[task.id] = task.to_json
      end

      def set_progress(id : String, value : Int, description : String)
        report = Mel::Progress::Report.new(id, description, value)
        @memory.progress[id] = ProgressEntry.new(report.to_json)
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
