require 'rubygems'
require 'batchbase'

# usage type 1

include Batchbase::Core
create_logger('/tmp/batchbase_test_sample1.log')

execute do
  logger.info 'test'
  logger.info env[:pid_file]
end
