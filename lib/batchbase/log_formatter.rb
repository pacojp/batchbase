#
# just simple. does not care instance or singleton ,,,,,,
#
module Batchbase
  class LogFormatter
    def self.log(log_type,message, is_base_info = true)

      # ......nangiyana
      message.gsub!(/\r\n/,"\n")
      message.gsub!(/\r/,"\n")

      messages = message.split("\n")
      if messages.size > 1
        messages.each_with_index do |st,i|
          next if st == ""
          if i == 0
            puts "[#{Time.now.strftime("%Y/%m/%d %H:%M:%S")}][#{$$}][#{log_type.to_s}] #{st}"
          else
            puts "[#{log_type.to_s}] #{st}"
          end
        end
      else
        if message != ""
          if is_base_info
            puts "[#{Time.now.strftime("%Y/%m/%d %H:%M:%S")}][#{$$}][#{log_type.to_s}] #{message}"
          else
            puts "[#{log_type.to_s}] #{message}"
          end
        end
      end
    end

    def self.error(message)
      if message.is_a? Exception
        self.log(:ERROR,"#{message.message}")
        message.backtrace.each_with_index {|line, i|
          self.log(:ERROR,"#{line})",false)
        }
      else
        self.log(:ERROR,message.to_s)
      end
    end

    def error(message)
      self.class.error(message)
    end

    def self.info(message)
      self.log(:INFO,message)
    end

    def info(message)
      self.class.info(message)
    end

    def self.warn(message)
      self.log(:WARN,message)
    end

    def warn(message)
      self.class.warn(message)
    end

    def self.notice(message)
      self.log(:NOTICE,message)
    end

    def notice(message)
      self.class.notice(message)
    end

    def self.alert(message)
      self.log(:ALERT,message)
    end

    def alert(message)
      self.class.alert(message)
    end

    def self.critical(message)
      self.log(:CRITICAL,message)
    end

    def critical(message)
      self.class.critical(message)
    end

    def self.debug(message)
      if $DEBUG
        self.log(:DEBUG,message)
      end
    end

    def debug(message)
      self.class.debug(message)
    end
  end
end
