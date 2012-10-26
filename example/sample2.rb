require 'rubygems'
require 'batchbase'

# usage type 2

class Batch
  include Batchbase::Core

  def proceed
    opts = self.option_parser
    options_arg = {:favorite_number=>777} #初期値を設定
    opts.on("-f", "--favorite_number=value",
           Integer,"favo"
            ) do |v|
      env[:favorite_number] = v
    end

    execute(options_arg) do
      logger.info env.inspect
      if env[:favorite_number]
        logger.info env[:favorite_number].to_s
      else
        logger.info 'fovorite_number not set'
      end
      logger.info 'info message'
    end
  end
end

b = Batch.new
b.proceed
