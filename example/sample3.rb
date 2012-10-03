
require 'rubygems'
require 'batchbase'

# usage type 1

include Batchbase::Core
@l = Batchbase::LogFormatter.new

execute(:daemonize=>true) do
  @l.info 'test'
  @l.info env[:pid_file]
  3600.times do
    sleep 1
  end
end
