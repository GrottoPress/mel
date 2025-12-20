module Mel
  # This saves a worker's currently running tasks in memory.
  #
  # Every time a worker polls for tasks, it updates the timestamp (score) of
  # its running tasks in the store. The Pool is how it knows which tasks to
  # update.
  module RunPool
    extend self

    @@mutex = Mutex.new
    @@pool = Set(String).new

    def fetch : Set(String)
      lock { @@pool }
    end

    def update(*ids : String)
      update(ids)
    end

    def update(ids : Indexable) : Set(String)
      lock { @@pool.concat(ids.map &.as String) }
    end

    def delete(*ids : String)
      delete(ids)
    end

    def delete(ids : Indexable) : Set(String)
      lock { @@pool.subtract(ids) }
    end

    def delete : Set(String)
      lock { @@pool = Set(String).new }
    end

    private def lock(&)
      @@mutex.synchronize { yield }
    end
  end
end
