
require 'rubygems'
require 'batchbase'

# usage type 3

include Batchbase::Core
create_logger('/tmp/batchbase_test_sample3.log')

def receive_signal(signal)
  logger.info("receive signal #{signal}")
  @stop = true
end

@stop = false

set_signal_observer(:receive_signal)

# :process_nameを指定するとps時の名前を指定できる
execute(:daemonize=>true,:process_name=>'batchbase_sample3') do
  logger.info 'test'
  logger.info env[:pid_file]
  3600.times do
    logger.info Time.now.strftime("%Y/%m/%d %H:%M:%S")
    sleep 1
    break if @stop
  end
end
