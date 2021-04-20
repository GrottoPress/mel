class CounterJob
  include Mel::Job

  def initialize(@max : Int32)
  end

  def run
    return if @max < 1

    run do |redis|
      @max.times { |count| CountJob.run(count: count, redis: redis) }
    end
  end
end
