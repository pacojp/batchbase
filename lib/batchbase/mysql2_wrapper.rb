# -*- coding: utf-8 -*-

require 'yaml'

class Batchbase::Mysql2Wrapper
  attr_accessor :client,:output_query_log

  QUERY_BASE_COLOR    = 35
  QUERY_SPECIAL_COLOR = 31

  def initialize(config)
    self.output_query_log = true
    Batchbase::LogFormatter.info "mysql2 client created with #{config.inspect}"
    self.client = Mysql2::Client.new(config)
    # サーバが古いので一応問題あるけど以下の方向で
    # http://kennyqi.com/archives/61.html
    self.class.query(self.client,"SET NAMES 'utf8'")
    self.class.query(self.client,"SET SQL_AUTO_IS_NULL=0")
  end

  # TODO 実行時間。更新項目数
  def self.query(client,str,output_query_log=true,color=QUERY_BASE_COLOR)
    s = Time.now
    ret = client.query(str)
    e = Time.now
    if output_query_log
      Batchbase::LogFormatter.info "[QUERY] "" \e[#{color}m (#{((e-s)*1000).round(2)}ms) #{str}\e[0m"
    end
    ret
  end

  def query(str,color=QUERY_BASE_COLOR)
    self.class.query(self.client,str,self.output_query_log,color)
  end

  def transaction(&proc)
    raise ArgumentError, "No block was given" unless block_given?
    #query "SET AUTOCOMMIT=0;",QUERY_SPECIAL_COLOR
    query "BEGIN",QUERY_SPECIAL_COLOR
    begin
      yield
      query "COMMIT",QUERY_SPECIAL_COLOR
    rescue => e
      query "ROLLBACK",QUERY_SPECIAL_COLOR
      raise e
    end
  end

  def self.make_config_key_symbol(config)
    new_config = {}
    config.each do |key,value|
      new_config[key.to_sym] = value
    end
    config = new_config
  end

  def self.config_from_yml(yml_path,environment,db_name=nil)
    db_config = YAML.load_file(yml_path)[environment]
    if db_name
      db_config = Batchbase::Mysql2Wrapper.make_config_key_symbol(db_config[db_name])
    else
      db_config = Batchbase::Mysql2Wrapper.make_config_key_symbol(db_config)
    end
    db_config
  end
end
