
# -*- coding: utf-8 -*-

$: << File.dirname(__FILE__)
require 'test_helper'
# usage type 1
#
include Batchbase::Core
@l = Batchbase::LogFormatter.new

opts=OptionParser.new
options = {}
opts.on("-x", "--xxxx",
       String,"xxx"
        ) do |v|
  options[:xxx] = v
end

set_option_parser(opts)

execute(options) do
  sleep 2
  @l.info 'test'
end
