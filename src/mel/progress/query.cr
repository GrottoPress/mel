struct Mel::Progress
  struct Query
    getter :id

    def initialize(@id : String)
    end

    def key
      self.class.key(id)
    end

    def get
      get(Mel.redis)
    end

    def get(redis)
      redis.hgetall(key)
    end

    def set(value, description)
      Mel.redis.multi { |redis| set(value, description, redis) }
    end

    def set(value : Int, description : String, redis)
      redis.hset(
        key,
        description: description,
        id: id,
        value: value.to_s
      )

      Mel.settings.progress_expiry.try do |expiry|
        redis.expire(key, expiry.total_seconds.to_i64)
      end
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
