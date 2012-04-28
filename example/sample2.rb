require 'rubygems'
require 'batchbase'

# usage type 2

class Batch < Batchbase::LogFormatter
  include Batchbase::Core

  def proceed
    execute do
      info 'info message'
      raise 'error'
    end
  end
end

b = Batch.new
b.proceed
