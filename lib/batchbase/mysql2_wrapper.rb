# -*- coding: utf-8 -*-

class Batchbase::Mysql2Wrapper
  attr_accessor :client

  def initialize(config)
    Batchbase::LogFormatter.info "mysql2 client created with #{config.inspect}"
    self.client = Mysql2::Client.new(config)
  end

  def query(str)
    Batchbase::LogFormatter.info "[QUERY] " + str
    self.client.query(str)
  end
end
