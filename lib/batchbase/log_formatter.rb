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
        log(:ERROR,"#{message.message}")
        message.backtrace.each_with_index {|line, i|
          log(:ERROR,"#{line})",false)
        }
      else
        log(:ERROR,message.to_s)
      end
    end

    def self.info(message)
      log(:INFO,message)
    end

    def sefl.warn(message)
      log(:WARN,message)
    end

    def self.notice(message)
      log(:NOTICE,message)
    end

    def self.alert(message)
      log(:ALERT,message)
    end

    def self.critical(message)
      log(:CRIT,message)
    end

    def self.debug(message)
      if $DEBUG
        log(:DEBUG,message)
      end
    end
  end
end
