module Mel::Carbon::EmailJob
  macro included
    include Mel::Now

    def initialize(@email : {{ @type.name.gsub(/Job$/, "") }})
    end

    def run
      @email.deliver
    end
  end
end

{% for klass in Carbon::Email.all_subclasses.reject(&.abstract?) %}
  struct {{ klass }}Job
    include Mel::Carbon::EmailJob
  end
{% end %}
