require 'rubygems'
require 'batchbase'

# usage type 2

class Batch < Batchbase::LogFormatter
  include Batchbase::Core

  def proceed
    execute do |env|
      p env
      info 'info message'
      raise 'error'
    end
  end
end

b = Batch.new
b.proceed
