module Mel::Job::Template
  macro included
    include JSON::Serializable

    # Fixes compile error:
    #
    # "Error: wrong number of arguments for 'CollectJobsJob.new'
    # (given 0, expected 1)"
    macro finished
      \{% if !@type.methods.map(&.name).includes?(:initialize.id) %}
        def initialize
        end
      \{% end %}
    end

    @__type__ : String = name

    def run
      \{% raise "#{@type}#run not implemented" %}
    end

    def before_run
    end

    def after_run(success)
    end

    def before_enqueue
    end

    def after_enqueue(success)
    end

    def before_dequeue
    end

    def after_dequeue(success)
    end

    private def redis
      Mel.redis
    end
  end
end
