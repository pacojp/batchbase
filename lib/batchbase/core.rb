# -*- coding: utf-8 -*-
require 'digest/md5'
require "optparse"

module Batchbase
  module Core
    def option_parser
      @options ||= OptionParser.new
    end

    # [options]
    #   プログラムより指定するバッチ動作オプション（ハッシュ値）
    #   :double_process_check
    #   :auto_recover
    #
    # バッチの主処理をこのメソッドへのブロック引数として定義してください
    #
    #   require 'rubygems'
    #   require 'batchbase'
    #
    #   include Batchbase::Core
    #
    #   execute() do
    #     info "batch process01"
    #   end
    #
    def execute(options={},&process)

      options[:double_process_check] = true unless options.key?(:double_process_check)
      options[:auto_recover] = true unless options.key?(:auto_recover)

      double_process_check = options[:double_process_check]
      auto_recover         = options[:auto_recover]

      opts = option_parser()
      pg_path = nil

      # 2010/03/10 追加機能 まだrailsバッチ以外での動作をテストしてません
      opts.on("--not_rails","set if this batch is not rails batch") do |v|
        ;
      end      

      if Module.constants.include?("ARGV_ORIGINAL")

        Batchbase::LogFormatter.debug "ARGV_ORIGINAL found!!"

        ARGV << "-h" if ARGV_ORIGINAL.include?("-h")
        ARGV << "--help" if ARGV_ORIGINAL.include?("--help")
        script_name = File.basename(ARGV_ORIGINAL[0])
        pg_path = File.expand_path(script_name)
        opts.banner = "Usage: script/runner #{script_name} [options]"

        Batchbase::LogFormatter.debug "pg_path=#{pg_path}"
        opts.on("-e", "--environment=name", 
                String,"specifies the environment for the runner to operate under (test/development/production).",
          "default: development")
      else
        Batchbase::LogFormatter.debug "caller=#{caller}"
        pg_path = if File.expand_path(caller[0]) =~ /(.*):\d*:in `.*?'\z/
                    $1
                  else
                    raise "must not happen!! can not get caller value"
                  end

        # 
        unless ARGV.include?("--not_rails")
          opts.on("-e", "--environment=name", 
                  String,"specifies the environment for the runner to operate under (test/development/production).",
            "default: development")
        end
      end

      opts.on("-h","--help","show this help message.") { $stderr.puts opts; exit }

      pid_file = nil
      opts.on("--lockfile LOCK_FILE_PATH","set lock file path") do |v|
        double_process_check = true unless double_process_check
        pid_file = v 
      end
      opts.on("--double_process_check_off","disable double process check") do |v|
        double_process_check = false
      end
      opts.on("--auto_recover_off","disable auto recover mode") do |v|
        auto_recover = false
      end

      opts.parse!(ARGV)

      Batchbase::LogFormatter.info "start script(#{pg_path})"
      script_started_at = Time.now
      double_process_check_worked = false
      begin
        # double process check
        if double_process_check
          #pg_path = File.expand_path($0)
          pg_name = File.basename(pg_path)
          hash = Digest::MD5.hexdigest(pg_path)
          pid_file = "/tmp/.#{pg_name}.#{hash}.pid" unless pid_file
          Batchbase::LogFormatter.debug pid_file
          if File.exists?(pid_file)
            pid = File.open(pid_file).read.chomp
            pid_list = `ps ax | awk '{print $1}'`
            if (pid != nil && pid != "" ) && pid_list =~ /#{pid}/
              Batchbase::LogFormatter.warn "pid:#{pid} still running"
              double_process_check_worked = true
              return nil
            else
              if auto_recover
                Batchbase::LogFormatter.warn "lock file still exists[pid=#{pid}],but process does not found.auto_recover enabled.so process continues"
              else
                double_process_check_worked = true
                raise "lock file still exists[pid=#{pid}],but process does not found.auto_recover disabled.so process can not continue"
              end
            end
          end
          File.open(pid_file, "w"){|file|
            file.write $$
          }
        end
        return (yield process)
      rescue => e
        Batchbase::LogFormatter.error e
      ensure
        unless double_process_check_worked
          File.delete(pid_file) if double_process_check
        end
        Batchbase::LogFormatter.info "finish script (%1.3fsec)" % (Time.now - script_started_at)
      end
    end
  end
end
