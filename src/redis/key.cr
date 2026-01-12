
struct Mel::Redis
  struct Key
    getter :namespace

    def initialize(@namespace : Symbol | String)
    end

    def name(*parts : Symbol | String) : String
      name_parts(name, parts)
    end

    def name : String
      "#{namespace}:tasks"
    end

    def progress(*parts : Symbol | String) : String
      name_parts(progress, parts)
    end

    def progress : String
      "#{namespace}:progress"
    end

    private def name_parts(name, parts)
      "#{name}:#{parts.join(':', &.to_s)}"
    end
  end
end
