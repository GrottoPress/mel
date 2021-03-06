struct Mel::Progress
  struct Query
    include JSON::Serializable

    getter :id

    def initialize(@id : String)
    end

    def key
      self.class.key(id)
    end

    def set(value)
      set(value, Mel.redis)
    end

    def set(value, redis)
      expiry = Mel.settings.progress_expiry.try(&.total_seconds.to_i64)
      redis.set(key, value.to_s, ex: expiry)
    end

    def get
      get(Mel.redis)
    end

    def get(redis)
      redis.incrby(key, 0)
    end

    def increment(by value)
      Mel.redis.multi { |redis| increment(value, redis) }
    end

    def increment(by value, redis)
      redis.incrby(key, value)

      Mel.settings.progress_expiry.try do |expiry|
        redis.run({"EXPIRE", key, expiry.total_seconds.to_i64.to_s})
      end
    end

    def decrement(by value)
      Mel.redis.multi { |redis| decrement(value, redis) }
    end

    def decrement(by value, redis)
      redis.decrby(key, value)

      Mel.settings.progress_expiry.try do |expiry|
        redis.run({"EXPIRE", key, expiry.total_seconds.to_i64.to_s})
      end
    end

    def self.key
      "mel:progress"
    end

    def self.key(*parts : String)
      "#{key}:#{parts.join(':')}"
    end

    def self.truncate
      keys = Mel.redis.keys("#{key}*")
      Mel.redis.run(["DEL"] + keys) unless keys.empty?
    end
  end
end
