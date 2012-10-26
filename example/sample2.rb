require 'rubygems'
require 'batchbase'

# usage type 2

DEFAULT_TEXT      = 'without test'
DEFAULT_TEXT_TEST = 'test'

class Batch
  include Batchbase::Core

  def initialize
    # 初期値設定
    env_defaults = {:favorite_number=>1}
    # オプションパーサーの設定追加
    opts = self.option_parser
    opts.on("-f", "--favorite_number=value",
           Integer,"favo"
            ) do |v|
      env[:favorite_number] = v
    end
    # ここでオプションをパースしておく
    parse_options(env_defaults)
  end

  def proceed(text)
    execute do
      logger.info env.inspect
      logger.info text
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
case b.env[:environment]
when 'test'
  b.proceed(DEFAULT_TEXT_TEST)
else
  b.proceed(DEFAULT_TEXT)
end

