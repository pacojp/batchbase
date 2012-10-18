# -*- coding: utf-8 -*-

$: << File.dirname(__FILE__)
require 'test_helper'
require 'batch'
require 'Fileutils'

include Batchbase::Core

create_logger('/dev/null')

def receive_signal(sig)
  logger.info("receive signal #{sig}")
  @shutdown = true
end

result = execute do
  set_signal_observer(:receive_signal)
  4.times do
    logger.info('logged by pg_for_test')
    sleep 1
    break if @shutdown
  end
  999999
end

File.write(FILE_PG_TEST,result.to_s)

