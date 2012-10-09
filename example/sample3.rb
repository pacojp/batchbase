
require 'rubygems'
require 'batchbase'

# usage type 1

include Batchbase::Core

execute(:daemonize=>true) do
  logger.info 'test'
  logger.info env[:pid_file]
  3600.times do
    sleep 1
  end
end
