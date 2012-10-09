require 'rubygems'
require 'batchbase'

# usage type 1

include Batchbase::Core

execute do
  logger.info 'test'
  logger.info env[:pid_file]
end
