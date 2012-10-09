require 'rubygems'
require 'batchbase'

# usage type 1

include Batchbase::Core

execute do
  create_logger('/tmp/batchbase_test_sample1.log')
  logger.info 'test'
  logger.info env[:pid_file]
end
