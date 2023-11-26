abstract class Mel::Task
  module Query
    def find_pending(count = -1, *, delete = false)
      return if count.zero?
      delete = false if delete.nil?

      connect do
        ids = Mel.redis.zrangebyscore(
          key,
          worker_score,
          worker_score,
          {"0", count.to_s}
        ).as(Array)

        find(ids, delete: delete)
      end
    end

    def find(ids : Indexable, *, delete = false)
      return if ids.empty?
      return previous_def unless delete.nil?

      connect do
        scores_ids = ids.join(",#{worker_score},").split(',')

        values = Mel.redis.multi do |redis|
          redis.mget(keys ids)
          redis.zadd(key, ["XX", worker_score] + scores_ids)
        end

        values = values[0].as(Array)
        values unless values.empty?
      end
    end

    private def worker_score
      "-#{Mel.settings.worker_id.abs}"
    end
  end
end
