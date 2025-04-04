class CounterJob
  include Mel::Job

  def initialize(@max : Int32)
  end

  def run
    return if @max < 1

    Mel.transaction do |store|
      @max.times { |count| CountJob.run(count: count, store: store) }
    end
  end
end
