class Mel::Carbon::DeliverLaterStrategy < Carbon::DeliverLaterStrategy
  def run(email, &block)
    {% begin %}
    case email
    {{ ::Carbon::Email.all_subclasses.reject(&.abstract?).map do |klass|
      "in #{klass}\n      #{klass}Job.run(email: email)"
    end.join("\n    ").id }}
    end
    {% end %}
  end
end
