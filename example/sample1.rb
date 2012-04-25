
require 'rubygems'
require 'batchbase'

include Batchbase::Core
@logger = Batchbase::LogFormatter

execute do
  puts test
end
