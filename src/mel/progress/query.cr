struct Mel::Progress
  struct Query
    include JSON::Serializable

    getter :id

    def initialize(@id : String)
    end

    def key
      "mel:progress:#{id}"
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
  end
end
