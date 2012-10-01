require 'rubygems'
require 'batchbase'

# usage type 1

include Batchbase::Core
@l = Batchbase::LogFormatter.new

opts = self.option_parser
opts.on("-x", "--xxxx",
       String,"xxx"
        ) do |v|
  env[:xxx] = v
end

execute do
  @l.info 'test'
  @l.info env[:pid_file]
  @l.info env[:xxx] ||= 'null'
end
