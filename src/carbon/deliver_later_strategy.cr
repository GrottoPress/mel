class Mel::Carbon::DeliverLaterStrategy < Carbon::DeliverLaterStrategy
  def run(email, &block)
    {% begin %}
    case email
    {% for klass in ::Carbon::Email.all_subclasses.reject(&.abstract?) %}
    in {{ klass }}
    {{ klass }}Job.run(email: email)
    {% end %}
    end
    {% end %}
  end
end

{% for klass in Carbon::Email.all_subclasses.reject(&.abstract?) %}
struct {{ klass }}Job
  include Mel::Job::Now

  def initialize(@email : {{ klass }})
  end

  def run
    @email.deliver
  end
end
{% end %}
