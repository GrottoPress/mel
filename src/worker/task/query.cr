abstract class Mel::Task
  module Query
    private LUA = <<-'LUA'
      local function scores_ids(ids, score)
        local results = {}

        for _, value in ipairs(ids) do
          table.insert(results, score)
          table.insert(results, value)
        end

        return results
      end

      local unpack = table.unpack or unpack
      local ids = redis.call('ZRANGEBYSCORE', KEYS[1], 0, ARGV[1], 'LIMIT', 0, ARGV[2])

      if #ids ~= 0 then
        redis.call('ZADD', KEYS[1], 'XX', unpack(scores_ids(ids, ARGV[3])))
      end

      return ids
      LUA

    def find_lt(
      time : Time,
      count : Int = -1,
      *,
      delete : Bool? = false
    ) : Array(String)?
      return if count.zero?
      return previous_def unless delete.nil?

      connect do
        ids = Mel.redis
          .eval(LUA, {key}, {"(#{time.to_unix}", count.to_s, worker_score})
          .as(Array)

        find(ids, delete: false)
      end
    end

    def find_lte(
      time : Time,
      count : Int = -1,
      *,
      delete : Bool? = false
    ) : Array(String)?
      return if count.zero?
      return previous_def unless delete.nil?

      connect do
        ids = Mel.redis
          .eval(LUA, {key}, {time.to_unix.to_s, count.to_s, worker_score})
          .as(Array)

        find(ids, delete: false)
      end
    end

    def find(count : Int, *, delete : Bool? = false) : Array(String)?
      return if count.zero?
      return previous_def unless delete.nil?

      connect do
        ids = Mel.redis
          .eval(LUA, {key}, {"+inf", count.to_s, worker_score})
          .as(Array)

        find(ids, delete: false)
      end
    end

    def find_pending(count : Int, *, delete : Bool = false) : Array(String)?
      return if count.zero?

      connect do
        ids = Mel.redis
          .zrangebyscore(key, worker_score, worker_score, {"0", count.to_s})
          .as(Array)

        find(ids, delete: delete)
      end
    end

    private def worker_score
      "-#{Mel.settings.worker_id.abs}"
    end
  end
end
