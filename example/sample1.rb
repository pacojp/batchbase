require 'rubygems'
require 'batchbase'

# usage type 1

include Batchbase::Core
@l = Batchbase::LogFormatter.new

execute do
  @l.info 'test'
end
