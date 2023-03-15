Spec.before_each do
  Mel.stop
  Mel::Task::Query.truncate
  Mel::Progress::Query.truncate
end

Spec.after_suite do
  Mel.stop
  Mel::Task::Query.truncate
  Mel::Progress::Query.truncate
end
