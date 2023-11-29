abstract class Mel::Task
  module Query
    def find(ids : Indexable, *, delete = false) : Array(String)?
      return if ids.empty?
      return previous_def unless delete.nil?

      connect do
        ids = ids.map(&.to_s)
        scores_ids = ids.flat_map { |id| {worker_score, id}.each }

        values = Mel.redis.multi do |redis|
          redis.mget(keys ids)
          redis.zadd(pending_key, ["NX"] + scores_ids)
          redis.zrem(key, ids)
          ids.each { |id| redis.run({"RENAME", key(id), pending_key(id)}) }
        end

        values = values.first.as(Array).compact_map(&.as? String)
        values unless values.empty?
      end
    end

    def find_pending(count : Int, *, delete = false) : Array(String)?
      return if count.zero?

      connect do
        ids = Mel.redis.zrangebyscore(
          pending_key,
          worker_score,
          worker_score,
          {"0", count.to_s}
        ).as(Array)

        find_pending(ids, delete: delete)
      end
    end

    def find_pending(id : String, *, delete = false) : String?
      find_pending({id}, delete: delete).try(&.first?)
    end

    def find_pending(ids : Indexable, *, delete = false) : Array(String)?
      return if ids.empty?

      connect do
        pending_keys = pending_keys(ids)

        values = Mel.redis.multi do |redis|
          redis.mget(pending_keys)

          if delete
            redis.zrem(pending_key, ids.map(&.to_s))
            redis.del(pending_keys)
          end
        end

        values = values.first.as(Array).compact_map(&.as? String)
        values unless values.empty?
      end
    end

    def delete_pending(id : String)
      find_pending(id, delete: true)
    end

    def delete_pending(ids : Indexable)
      find_pending(ids, delete: true)
    end

    def pending_key : String
      key("pending")
    end

    def pending_key(*parts : String) : String
      "#{pending_key}:#{parts.join(':')}"
    end

    def pending_keys(ids : Indexable)
      ids.map { |id| pending_key(id.to_s) }
    end

    private def worker_score
      Mel.settings.worker_id.to_s
    end
  end
end
