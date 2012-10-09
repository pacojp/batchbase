

# -*- coding: utf-8 -*-

$: << File.dirname(__FILE__)
require 'test_helper'

require 'batch'
require 'logger'

class CheckLogger
  def self.check
    logger = Logger.new(STDERR)
    logger.formatter = Batchbase::LogFormatter.formatter
    logger.info 'test'
    logger.info 1
    begin
      raise 'some error'
    rescue => e
      logger.error e
    end

    logger = Logger.new("/dev/null")
    logger.formatter = Batchbase::LogFormatter.formatter
    logger.info 'should not show'
  end
end

CheckLogger.check


