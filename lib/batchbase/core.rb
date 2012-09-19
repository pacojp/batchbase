# -*- coding: utf-8 -*-
require 'digest/md5'
require "optparse"

module Batchbase
  module Core
    def option_parser(v=OptionParser.new)
      @options ||= v
    end

    def environment
      @__env
    end

    # [options]
    #   プログラムより指定するバッチ動作オプション（ハッシュ値）
    #   :double_process_check 初期値 true
    #   :auto_recover         初期値 false
    #
    # バッチの主処理をこのメソッドへのブロック引数として定義してください
    #
    #   require 'rubygems'
    #   require 'batchbase'
    #
    #   include Batchbase::Core
    #
    #   execute do
    #     p environment
    #     info "batch process01"
    #   end
    #
    def execute(options={},&process)
      double_process_check = true unless options.key?(:double_process_check)
      auto_recover         = false unless options.key?(:auto_recover)

      opts = option_parser()
      pg_path = nil

      Batchbase::LogFormatter.debug "caller=#{caller}"
      pg_path = if File.expand_path(caller[0]) =~ /(.*):\d*:in `.*?'\z/
        $1
      else
        raise "must not happen!! can not get caller value"
      end

      env = 'development'
      opts.on("-e", "--environment=name", 
        String,"specifies the environment",
        "default: development") do |v|
        env = v
      end

      opts.on("-h","--help","show this help message.") { $stderr.puts opts; exit }

      pid_file = nil
      opts.on("--lockfile LOCK_FILE_PATH","set lock file path") do |v|
        double_process_check = true
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
          pid_file ||= "/tmp/.#{pg_name}.#{hash}.pid"

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
                Batchbase::LogFormatter.warn "lock file still exists[pid=#{pid}:file=#{pid_file}],but process does not found.auto_recover enabled.so process continues"
              else
                double_process_check_worked = true
                raise "lock file still exists[pid=#{pid}:file=#{pid_file}],but process does not found.auto_recover disabled.so process can not continue"
              end
            end
          end
          File.open(pid_file, "w"){|file|
            file.write $$
          }
        end

        e = {}
        e[:double_process_check] = double_process_check
        e[:auto_recover]         = auto_recover
        e[:env]                  = env
        e[:pg_path]              = pg_path
        e[:pid_file]             = pid_file
        @__env = e
        return yield(process)
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
