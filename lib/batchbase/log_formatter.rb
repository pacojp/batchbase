#
# just simple. does not care instance or singleton ,,,,,,
#
module Batchbase
  class LogFormatter
    def self.formatter
      proc do |severity, datetime, progname, message|
        log = ""
        case message
        when Exception
          message = message.message + "\n" + message.backtrace.join("\n")
        when Numeric
          message = message.to_s
        end
        message.gsub!(/\r\n/,"\n")
        message.gsub!(/\r/,"\n")

        messages = message.split("\n")
        if messages.size > 1
          messages.each_with_index do |st,i|
            next if st == ""
            if i == 0
              log << "[#{datetime.strftime("%Y/%m/%d %H:%M:%S")}][#{$$}][#{severity}] #{st}\n"
            else
              log << "[#{severity}] #{st}\n"
            end
          end
        else
          if message != ""
            log << "[#{datetime.strftime("%Y/%m/%d %H:%M:%S")}][#{$$}][#{severity}] #{message}\n"
          end
        end

        log
      end
    end
  end
end
