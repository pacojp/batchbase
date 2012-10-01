require 'rubygems'
require 'batchbase'

# usage type 2

class Batch < Batchbase::LogFormatter
  include Batchbase::Core

  def proceed
    opts = self.option_parser
    opts.on("-f", "--favorite_number=value",
           Integer,"favo"
            ) do |v|
      env[:favorite_number] = v
    end

    execute do
      info env.inspect
      info env[:favorite_number]
      info 'info message'

      # データベース
      db_yml_path = File::dirname(env[:pg_path]) + '/../config/database.yml'
      # 第3引数は複数DB接続が無いならば指定不要
      db_config = Batchbase::Mysql2Wrapper.config_from_yml(db_yml_path,env[:env],'some_database')

      client = Batchbase::Mysql2Wrapper.new(db_config)
      # クエリログがうざいなら
      #client.output_query_log = false
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
