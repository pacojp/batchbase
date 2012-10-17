# -*- coding: utf-8 -*-

$: << File.dirname(__FILE__)
require 'test_helper'
require 'batch'
require 'Fileutils'

include Batchbase::Core

create_logger('/dev/null')

result = execute do
  sleep 4
  Batch::DOUBLE_PROCESS_CHECK__OK
end

File.write(FILE_PG_TEST,result.to_s)

