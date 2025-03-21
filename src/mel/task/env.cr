abstract class Mel::Task
  # This saves a worker's currently running tasks in its environment.
  #
  # Each worker has an isolated environment, allowing us to scale Mel
  # without worrying about running a task multiple times.
  #
  # Every time a worker polls for tasks, it updates the timestamp of its
  # running tasks in the store. When the worker loses track of its tasks,
  # eg. after an abrupt shutdown, another worker will pick up those tasks
  # if their timestamps have not been updated since the last 3 polls.
  module Env
    extend self

    @@mutex = Mutex.new

    VAR = "RUNNING_TASKS"

    def fetch : Array(String)
      lock { unsafe_fetch }
    end

    def fetch_raw : String
      fetch.join(' ')
    end

    def update(*ids : String)
      update(ids)
    end

    def update(ids : Indexable)
      return if ids.empty?

      lock do
        unsafe_fetch.+(ids.map &.as String).uniq!.tap do |_ids|
          ENV[VAR] = _ids.join(' ')
        end
      end
    end

    def delete(*ids : String)
      delete(ids)
    end

    def delete(ids : Indexable)
      return if ids.empty?

      lock do
        unsafe_fetch.tap do |_ids|
          ids.each { |id| _ids.delete(id) }
          ENV[VAR] = _ids.join(' ')
        end
      end
    end

    def delete
      lock { ENV.delete(VAR) }
    end

    private def unsafe_fetch
      ENV.fetch(VAR, "").split.uniq!
    end

    private def lock
      @@mutex.synchronize { yield }
    end
  end
end
