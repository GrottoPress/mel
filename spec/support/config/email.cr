BaseEmail.configure do |settings|
  settings.adapter = Carbon::DevAdapter.new
  settings.deliver_later_strategy = Mel::Carbon::DeliverLaterStrategy.new
end
