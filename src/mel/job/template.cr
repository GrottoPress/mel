module Mel::Job::Template
  abstract def run

  macro included
    include JSON::Serializable

    # Define a default constructor where none is provided. This is necessary
    # because `JSON::Serializable` defines a `#initialize` method which
    # means the default constructor is never added by the compiler.
    #
    # Jobs requires a custom constructor to be present, even if unused,
    # otherwise we get a compile error:
    #
    # "Error: wrong number of arguments for 'CollectJobsJob.new'
    # (given 0, expected 1)" OR "Error: no overload matches 'CollectJobsJob.new'
    # with type "
    macro finished
      \{% if @type.methods.all? do |method|
        method.name != :initialize.id || method.args.any? { |arg|
          arg.restriction && arg.restriction.resolve == ::JSON::PullParser
        }
      end %}
        def initialize
        end
      \{% end %}
    end

    @__type__ : String = name

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
  end
end
