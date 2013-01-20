# -*- coding: utf-8 -*-
require 'digest/md5'
require "optparse"
require 'sys/proctable'
require 'logger'
require 'kanamei_log_formatter'

module Batchbase
  module Core

    SIGNALS = [ :QUIT, :INT, :TERM, :USR1, :USR2, :HUP ]
    #SIGNALS = [ :QUIT, :INT, :TERM ]

    DOUBLE_PROCESS_CHECK__OK                =  1
    DOUBLE_PROCESS_CHECK__AUTO_RECOVERD     =  2
    DOUBLE_PROCESS_CHECK__NG                =  0
    DOUBLE_PROCESS_CHECK__STILL_RUNNING     = -1
    DOUBLE_PROCESS_CHECK__SAME_PROCESS_NAME =  3

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

    #
    # 内部保持をするロガーを新規作成
    #
    def create_logger(io=STDERR,log_level=Logger::INFO)
      @__logger = Logger.new(io)
      @__logger.formatter = Kanamei::LogFormatter.formatter
      @__logger.level = log_level
      @__logger
    end

    #
    # 内部保持するロガーを引数にて設定
    #
    def set_logger(_logger)
      @__logger = _logger
    end

    #
    # ログを出力しないように設定（内部的にはログを出力するが、その向き先が/dev/nullって実装になってます）
    #
    def skip_logging
      create_logger("/dev/null")
    end

    #
    # 内部的には
    #   init
    #   parse_options_inner
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
      result = nil
      begin
        init
        parse_options_inner(options,ARGV)
        logger.info  "start script(#{pg_path})"
        logger.debug "caller=#{caller}"
        result = double_process_check_and_create_pid_file
        case result
        when DOUBLE_PROCESS_CHECK__OK,DOUBLE_PROCESS_CHECK__AUTO_RECOVERD
          if result == DOUBLE_PROCESS_CHECK__AUTO_RECOVERD
            logger.warn "lock file still exists[pid=#{env[:old_pid_from_pid_file]}:file=#{pid_file}],but process does not found.Auto_recover enabled.so process continues"
          end
          result = execute_inner(&process)
        when DOUBLE_PROCESS_CHECK__NG
          logger.error "lock file still exists[pid=#{env[:old_pid_from_pid_file]}:file=#{pid_file}],but process does not found.Auto_recover disabled.so process can not continue"
        when DOUBLE_PROCESS_CHECK__STILL_RUNNING
          logger.warn "pid:#{env[:old_pid_from_pid_file]} still running"
        when DOUBLE_PROCESS_CHECK__SAME_PROCESS_NAME
          logger.warn "process_name:#{env[:process_name]} still exists"
        else
          raise 'must not happen'
        end
      rescue => e
        logger.error e
      ensure
        release
        logger.info "finish script (%1.3fsec)" % (Time.now - @__script_started_at)
      end
      result
    end

    module ClassMethods
      def is_there_process(pid)
        pid = pid.to_i
        raise 'pid must be number' if pid == 0
        process = Sys::ProcTable.ps(pid)
        process != nil && process.state == 'run'
      end

      def env
      end
    end

    def self.included(mod)
      # ModuleのインスタンスmodがAをincludeした際に呼び出され、
      # A::ClassMethodsのインスタンスメソッドをmodに特異メソッドとして追加する。
      mod.extend ClassMethods
    end

    def signal_observers
      @__signal_observers ||= []
    end

    def set_signal_observer(method_name,object=self)
      @__signal_observers ||= []
      case method_name
      when String
        method_name = method_name.to_sym
      when Symbol
      else
        raise ArgumentError.new('method_name must be String or Symbol')
      end
      @__signal_observers << [object,method_name]
    end

    def parse_options(options,argv=ARGV)
      parse_options_inner(options,argv)
    end

    private

    def init
      SIGNALS.each { |sig| trap(sig){r_signal(sig)} }
      @__script_started_at = Time.now
      #raise 'already inited' if @__init
      return if @__init
      @__init   = true
      env[:pid] = $$
      if File.expand_path(caller[0]) =~ /(.*):\d*:in `.*?'\z/
        env[:pg_path] = $1
      else
        raise "must not happen!! can not get caller value"
      end
    end

    def parse_options_inner(options,argv)
      init
      return if @__parse_option
      @__parse_option = true
      options[:double_process_check] = true if options[:double_process_check].nil?
      options[:auto_recover] ||= false
      options[:environment]  ||= 'development'
      options[:pg_name]      ||= File.basename(pg_path)
      options[:pid_file]     ||= "/tmp/.#{env[:pg_name]}.#{Digest::MD5.hexdigest(pg_path)}.pid"
      options[:daemonize]    ||= false
      options.each do |k,v|
        env[k] = v
      end

      opts = option_parser

      opts.on("-e", "--environment name",
        String,"specifies the environment",
        "default: development") do |v|
        env[:environment] = v
      end

      opts.on("-d", "--daemonize") do
        env[:daemonize] = true
      end

      opts.on("-p", "--process_name name",
        String,"specifies the process name(it work with double process check)",
        "default: nil") do |v|
        env[:process_name] = v.clone.strip
      end

      opts.on("-h","--help","show this help message.") { $stderr.puts opts; exit }

      opts.on("--lockfile LOCK_FILE_PATH","set lock file path") do |v|
        double_process_check = true
        env[:pid_file] = v
      end
      opts.on("--log LOG_FILE_PATH","set log file path") do |v|
        env[:log] = v
        create_logger(v)
      end
      opts.on("--double_process_check_off","disable double process check") do |v|
        env[:double_process_check] = false
      end
      opts.on("--auto_recover","enable auto recover mode") do |v|
        env[:auto_recover] = true
      end

      opts.parse!(argv)

      if env[:process_name]
        $0 = env[:process_name]
      end

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

        if env[:process_name]
          Sys::ProcTable.ps do |other_process|
            if other_process.cmdline.strip == env[:process_name] && $$ != other_process.pid
              env[:double_process_check_problem] = true
              return DOUBLE_PROCESS_CHECK__SAME_PROCESS_NAME
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
      sent_signal = false
      signal_observers.each do |ar|
        begin
          ar[0].send ar[1],signal
          sent_signal = true
        rescue => e
          message = "signal #{signal} received. but can not call '#{method_name}'"
          env[:signal_error] = message
          logger.error(message)
        end
      end

      unless sent_signal
        trap(signal,"DEFAULT")
        Process.kill signal,$$
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
