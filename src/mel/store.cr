module Mel
  module Store
    abstract def find(count : Int, *, delete : Bool?)
    abstract def find(ids : Indexable, *, delete : Bool)
    abstract def find_due(at time : Time, count : Int, *, delete : Bool?)
    abstract def get_progress(ids : Indexable)
    abstract def transaction(& : Transaction -> _)
    abstract def truncate
    abstract def truncate_progress

    macro included
      def add(
        task : Mel::Task,
        store : Mel::Transaction? = nil, *,
        force = false
      )
        store ?
          store.add(task, force: force) :
          transaction &.add(task, force: force)
      end

      def create(task : Mel::Task, store : Mel::Transaction? = nil)
        store ? store.create(task) : transaction(&.create task)
      end

      def update(task : Mel::Task, store : Mel::Transaction? = nil)
        store ? store.update(task) : transaction(&.update task)
      end

      def delete(task : Mel::Task)
        delete(task.id)
      end

      def delete(tasks : Indexable(Mel::Task))
        delete(tasks.map &.id)
      end

      def delete(id : String)
        find(id, delete: true)
      end

      def delete(ids : Mel::Indexable)
        find(ids, delete: true)
      end

      def find(task : Mel::Task, *, delete : Bool? = false)
        find(task.id, delete: delete)
      end

      def find(tasks : Indexable(Mel::Task), *, delete : Bool? = false)
        find(tasks.map &.id, delete: delete)
      end

      def find(id, *, delete : Bool? = false)
        find({id}, delete: delete).try(&.first?)
      end

      def get_progress(task : Mel::Task)
        get_progress(task.id)
      end

      def get_progress(tasks : Indexable(Mel::Task))
        get_progress(tasks.map &.id)
      end

      def get_progress(id : String)
        get_progress({id}).try(&.first?)
      end

      def set_progress(
        task : Mel::Task,
        value : Int,
        description : String,
        store : Mel::Transaction? = nil
      )
        store ?
          store.set_progress(task, value, description) :
          transaction &.set_progress(task, value, description)
      end

      def set_progress(
        id,
        value : Int,
        description : String,
        store : Mel::Transaction? = nil
      )
        store ?
          store.set_progress(id, value, description) :
          transaction &.set_progress(id, value, description)
      end

      # We assume a task is orphaned if its score has not been updated after
      # 3 polls.
      private def orphan_after
        poll_interval = Mel.settings.poll_interval

        {poll_interval * 3, poll_interval + 1.second}.max
      end
    end
  end

  module Transaction
    abstract def create(task : Task)
    abstract def set_progress(id : String, value : Int, description : String)
    abstract def update(task : Task)

    macro included
      def add(task : Mel::Task, *, force = false)
        force ? update(task) : create(task)
      end

      def set_progress(task : Mel::Task, value : Int, description : String)
        set_progress(task.id, value, description)
      end
    end
  end
end
