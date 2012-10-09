# -*- coding: utf-8 -*-
require 'digest/md5'
require "optparse"
require 'sys/proctable'
require 'logger'

module Batchbase
  module Core

    #SIGNALS = [ :QUIT, :INT, :TERM, :USR1, :USR2, :HUP ]
    SIGNALS = [ :QUIT, :INT, :TERM ]

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

    #
    # loggerの出力をOFFにしたい場合は
    # 引数を"/dev/null"で渡してください
    #
    def logger
      @__logger ||= create_logger
    end

    def create_logger(io=STDERR,log_level=Logger::INFO)
      @__logger = Logger.new(io)
      @__logger.formatter = LogFormatter.formatter
      @__logger.level = log_level
      @__logger
    end

    def set_logger(_logger)
      @__logger = _logger
    end

    def skip_logging
      create_logger("/dev/null")
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
        logger.info  "start script(#{pg_path})"
        logger.debug "caller=#{caller}"
        parse_options(options,ARGV)
        result = double_process_check_and_create_pid_file
        case result
        when DOUBLE_PROCESS_CHECK__OK,DOUBLE_PROCESS_CHECK__AUTO_RECOVERD
          if result == DOUBLE_PROCESS_CHECK__AUTO_RECOVERD
            logger.warn "lock file still exists[pid=#{env[:old_pid_from_pid_file]}:file=#{pid_file}],but process does not found.Auto_recover enabled.so process continues"
          end
          execute_inner(&process)
        when DOUBLE_PROCESS_CHECK__NG
          logger.error "lock file still exists[pid=#{env[:old_pid_from_pid_file]}:file=#{pid_file}],but process does not found.Auto_recover disabled.so process can not continue"
        when DOUBLE_PROCESS_CHECK__STILL_RUNNING
          logger.warn "pid:#{env[:old_pid_from_pid_file]} still running"
        else
          raise 'must not happen'
        end
      rescue => e
        logger.error e
      ensure
        release
        logger.info "finish script (%1.3fsec)" % (Time.now - @__script_started_at)
      end
    end

    module ClassMethods
      def is_there_process(pid)
        pid = pid.to_i
        raise 'pid must be number' if pid == 0
        process = Sys::ProcTable.ps(pid)
        process != nil && process.state == 'run'
      end
    end

    def self.included(mod)
      # ModuleのインスタンスmodがAをincludeした際に呼び出され、
      # A::ClassMethodsのインスタンスメソッドをmodに特異メソッドとして追加する。
      mod.extend ClassMethods
    end

    def set_signal_observer(method_name)
      @__signal_observers ||= []
      case method_name
      when String
        method_name = method_name.to_sym
      when Symbol
      else
        raise ArgumentError.new('method_name must be String or Symbol')
      end
      @__signal_observers << method_name
    end

    private

    #
    # オプションのパース及び
    # ロックファイルの作成
    #
    def init
      SIGNALS.each { |sig| trap(sig){r_signal(sig)} }
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
      env[:daemonize]            = options[:daemonize]
      env[:daemonize]            = false if env[:daemonize] == nil
      env[:pid_file]             ||= "/tmp/.#{env[:pg_name]}.#{Digest::MD5.hexdigest(pg_path)}.pid"

      opts = option_parser

      opts.on("-e", "--environment=name",
        String,"specifies the environment",
        "default: development") do |v|
        env[:environment] = v
      end

      opts.on("-d", "--daemonize") do
        env[:daemonize] = true
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
        logger.debug pid_file
        if File.exists?(pid_file)
          pid = File.open(pid_file).read.chomp
          env[:old_pid_from_pid_file] = pid
          if (pid != nil && pid != "" ) && self.class.is_there_process(pid)
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

    #
    # receive_signal
    # 一応名前がバッティングしないように、、
    #
    def r_signal(signal)
      @__signal_observers.each do |method_name|
        begin
        self.send method_name,signal
        rescue => e
          logger.error("can not call '#{method_name}'")
        end
      end
    end

    def execute_inner(&process)
      @__executed = true
      if env[:daemonize]
        # HACKME logging
        logger.info "daemonized"
        env[:pid_old] = env[:pid]
        Process.daemon
        env[:pid] = Process.pid
        File.open(pid_file, "w"){|f|f.write env[:pid]}
        sleep 1
      end
      return yield(process)
    end
  end
end
