# -*- coding: utf-8 -*-
require 'digest/md5'
require "optparse"

module Batchbase
  module Core

    SIGNALS = [ :WINCH, :QUIT, :INT, :TERM, :USR1, :USR2, :HUP, :TTIN, :TTOU ]

    DOUBLE_PROCESS_CHECK__OK            =  1
    DOUBLE_PROCESS_CHECK__AUTO_RECOVERD =  2
    DOUBLE_PROCESS_CHECK__NG            =  0
    DOUBLE_PROCESS_CHECK__STILL_RUNNING = -1

    def option_parser
      @__option_parser ||= OptionParser.new
    end

    def set_option_parser(v)
      @__option_parser = v
    end

    def env
      @__env ||= {}
    end

    def executed
      @__executed
    end

    def pg_path;env[:pg_path];end

    def pid_file;env[:pid_file];end

    def __logger
      return @__logger if @__logger
      if self.respond_to?(:info)
        @__logger = self
      else
        @__logger = Batchbase::LogFormatter
      end
    end

    #
    # 内部的には
    #   init
    #   parse_options
    #   execute_inner
    #   release
    # の順にコールしてます
    #
    # [options]
    #   プログラムより指定するバッチ動作オプション（ハッシュ値）
    #   :double_process_check 初期値 true
    #   :auto_recover         初期値 false
    #
    def execute(options={},&process)
      begin
        init
        __logger.info  "start script(#{pg_path})"
        __logger.debug "caller=#{caller}"
        parse_options(options,ARGV)
        result = double_process_check_and_create_pid_file
        case result
        when DOUBLE_PROCESS_CHECK__OK,DOUBLE_PROCESS_CHECK__AUTO_RECOVERD
          if result == DOUBLE_PROCESS_CHECK__AUTO_RECOVERD
            __logger.warn "lock file still exists[pid=#{pid}:file=#{pid_file}],but process does not found.Auto_recover enabled.so process continues"
          end
          execute_inner(&process)
        when DOUBLE_PROCESS_CHECK__NG
          __logger.error "lock file still exists[pid=#{pid}:file=#{pid_file}],but process does not found.Auto_recover disabled.so process can not continue"
        when DOUBLE_PROCESS_CHECK__STILL_RUNNING
          __logger.warn "pid:#{pid} still running"
        else
          raise 'must not happen'
        end
      rescue => e
        __logger.error e
      ensure
        release
        __logger.info "finish script (%1.3fsec)" % (Time.now - @__script_started_at)
      end
    end

    private

    #
    # オプションのパース及び
    # ロックファイルの作成
    #
    def init
      @__script_started_at = Time.now
      raise 'already inited' if @__init
      @__init   = true
      env[:pid] = $$
      if File.expand_path(caller[0]) =~ /(.*):\d*:in `.*?'\z/
        env[:pg_path] = $1
      else
        raise "must not happen!! can not get caller value"
      end
    end

    def parse_options(options,argv)
      env[:double_process_check] = options[:double_process_check]
      env[:double_process_check] = true if env[:double_process_check] == nil
      env[:auto_recover]         = options[:auto_recover]
      env[:auto_recover]         = false if env[:auto_recover] == nil
      env[:environment]          = options[:environment] ||= 'development'
      env[:pg_name]              = File.basename(pg_path)
      env[:pid_file]             = options[:pid_file]
      env[:daemonized]           = options[:daemonized] ||= false
      env[:pid_file]             ||= "/tmp/.#{env[:pg_name]}.#{Digest::MD5.hexdigest(pg_path)}.pid"

      opts = option_parser

      opts.on("-e", "--environment=name",
        String,"specifies the environment",
        "default: development") do |v|
        env[:environment] = v
      end

      opts.on("-d", "--daemonize") do
        env[:daemonized] = true
        Batchbase::LogFormatter.info "daemonized"
        Process.daemon
      end

      opts.on("-h","--help","show this help message.") { $stderr.puts opts; exit }

      opts.on("--lockfile LOCK_FILE_PATH","set lock file path") do |v|
        double_process_check = true
        env[:pid_file] = v
      end
      opts.on("--double_process_check_off","disable double process check") do |v|
        env[:double_process_check] = false
      end
      opts.on("--auto_recover","enable auto recover mode") do |v|
        env[:auto_recover] = true
      end

      opts.parse!(argv)

      if env[:auto_recover] == true
        env[:double_process_check] = true
      end
    end

    def double_process_check_and_create_pid_file
      ret = DOUBLE_PROCESS_CHECK__OK
      if env[:double_process_check]
        double_process_check_worked = false
        #pg_path = File.expand_path($0)
        __logger.debug pid_file
        if File.exists?(pid_file)
          pid = File.open(pid_file).read.chomp
          pid_list = `ps ax | awk '{print $1}'`
          pid_list.gsub!(/\r\n/,"\n")
          pid_list.gsub!(/\r/,"\n")
          pid_list = "\n#{pid_list}\n"
          if (pid != nil && pid != "" ) && pid_list =~ /\n#{pid}\n/
            env[:double_process_check_problem] = true
            return DOUBLE_PROCESS_CHECK__STILL_RUNNING
          else
            if env[:auto_recover]
              ret = DOUBLE_PROCESS_CHECK__AUTO_RECOVERD
            else
              env[:double_process_check_problem] = true
              return DOUBLE_PROCESS_CHECK__NG
            end
          end
        end
        File.open(pid_file, "w"){|f|f.write $$}
        env[:double_process_check_worked] = double_process_check_worked
      end
      ret
    end

    def release
      # 2重起動チェックで問題があった場合はpid_fileを消してはいけないので
      unless env[:double_process_check_problem]
        File.delete(pid_file) if pid_file && File.exist?(pid_file)
      end
    end

    def execute_inner(&process)
      @__executed = true
      return yield(process)
    end
  end
end
