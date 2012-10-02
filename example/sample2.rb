require 'rubygems'
require 'batchbase'

# usage type 2

class Batch < Batchbase::LogFormatter
  include Batchbase::Core

  def proceed
    opts = self.option_parser
    opts.on("-f", "--favorite_number=value",
           Integer,"favo"
            ) do |v|
      env[:favorite_number] = v
    end

    execute do
      info env.inspect
      if env[:favorite_number]
        info env[:favorite_number].to_s
      else
        info 'fovorite_number not set'
      end
      info 'info message'
    end
  end
end

b = Batch.new
b.proceed
