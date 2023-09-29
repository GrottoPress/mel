struct Mel::Progress
  struct Query
    getter :id

    def initialize(@id : String)
    end

    def key
      self.class.key(id)
    end

    def get(redis = nil)
      redis ||= Mel.redis
      redis.get(key)
    end

    def set(value : Int, description : String, redis = nil)
      redis ||= Mel.redis
      report = Report.new(id, description, value)

      redis.set(key, report.to_json, ex: Mel.settings.progress_expiry)
    end

    def self.get(ids : Indexable, redis = nil)
      return if ids.empty?

      command = ->(_redis : Redis::Commands) do
        ids.map { |id| Query.new(id).get(_redis) }
      end

      return command.call(redis) if redis
      Mel.redis.multi { |_redis| command.call(_redis) }
    end

    def self.key
      "#{Mel.settings.redis_key_prefix}:progress"
    end

    def self.key(*parts : String)
      "#{key}:#{parts.join(':')}"
    end

    def self.truncate
      keys = Mel.redis.keys("#{key}*")
      Mel.redis.del(keys.map &.to_s) unless keys.empty?
    end
  end
end
