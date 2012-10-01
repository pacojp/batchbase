require 'rubygems'
require 'batchbase'

# usage type 1

include Batchbase::Core
@l = Batchbase::LogFormatter.new

execute do
  @l.info 'test'
  @l.info env[:pid_file]
  @l.info env[:xxx] ||= 'null'
end
