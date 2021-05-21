class CountJob
  include Mel::Job

  def initialize(@count : Int32)
  end

  def run
    puts @count
  end
end
