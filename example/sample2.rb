require 'rubygems'
require 'batchbase'

# usage type 2

class Batch < Batchbase::LogFormatter
  include Batchbase::Core

  def proceed
    execute do
      p environment
      info 'info message'

      db_yml_path = File::dirname(environment[:pg_path]) + '/../config/database.yml'
      # 第3引数は複数DB接続が無いならば指定不要
      db_config = Batchbase::Mysql2Wrapper.config_from_yml(db_yml_path,environment[:env],'some_database')

      client = Batchbase::Mysql2Wrapper.new(db_config)
      client.query "SELECT * FROM hoges"
      client.transaction do
        client.query 'SELECT * FROM hoges'
        raise 'error' # call ROLLBACK
      end
    end
  end
end

b = Batch.new
b.proceed
