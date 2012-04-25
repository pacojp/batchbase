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
    #   :error_mail_to
    #   :error_mail_from
    #   :error_mail_smtp_addr
    #   :error_mail_smtp_port
    #   :double_process_check
    #   :auto_recover
    #
    # バッチの主処理をこのメソッドへのブロック引数として定義してください
    #
    #   require 'rubygems'
    #   require 'batchbase'
    #
    #   include Batchbase::Base
    #
    #   execute() do
    #     info "batch process01"
    #   end
    #
    # railsのscript/runnerで使用する場合はscript/runnerを以下の感じでいじってから使用してください
    #
    #   #!/usr/bin/env ruby
    # 
    #   #original add start
    #   ARGV_ORIGINAL = ARGV.clone
    #   ARGV.delete("-h")
    #   ARGV.delete("--help")
    #   #original add end
    # 
    #   require File.dirname(__FILE__) + '/../config/boot'
    #   require 'commands/runner'
    #
    def execute(options={},&process)

      options[:error_mail_to] = nil unless options.key?(:error_mail_to)
      options[:error_mail_from] = nil unless options.key?(:error_mail_from)
      options[:error_mail_smtp_addr] = "127.0.0.1" unless options.key?(:error_mail_smtp_addr)
      options[:error_mail_smtp_port] = 25 unless options.key?(:error_mail_smtp_port)
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

        Keystone::Base::Logger.instance.debug "ARGV_ORIGINAL found!!"

        ARGV << "-h" if ARGV_ORIGINAL.include?("-h")
        ARGV << "--help" if ARGV_ORIGINAL.include?("--help")
        script_name = File.basename(ARGV_ORIGINAL[0])
        pg_path = File.expand_path(script_name)
        opts.banner = "Usage: script/runner #{script_name} [options]"

        Keystone::Base::Logger.instance.debug "pg_path=#{pg_path}"
        opts.on("-e", "--environment=name", 
                String,"specifies the environment for the runner to operate under (test/development/production).",
          "default: development")
      else
        Keystone::Base::Logger.instance.debug "caller=#{caller}"
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
      opts.on("--error_mail_to MAIL_ADDR") do |v|
        options[:error_mail_to] = v
      end
      opts.on("--error_mail_from MAIL_ADDR") do |v|
        options[:error_mail_from] = v
      end
      opts.on("--error_mail_smtp_addr IP_ADDR") do |v|
        options[:error_mail_smtp_addr] = v
      end
      opts.on("--error_mail_smtp_port PORT") do |v|
        options[:error_mail_smtp_port] = Integer(v)
      end

      opts.parse!(ARGV)

      Keystone::Base::Logger.instance.info "start script(#{pg_path})"
      script_started_at = Time.now
      double_process_check_worked = false
      begin
        # double process check
        if double_process_check
          #pg_path = File.expand_path($0)
          pg_name = File.basename(pg_path)
          hash = Digest::MD5.hexdigest(pg_path)
          pid_file = "/tmp/.#{pg_name}.#{hash}.pid" unless pid_file
          Keystone::Base::Logger.instance.debug pid_file
          if File.exists?(pid_file)
            pid = File.open(pid_file).read.chomp
            pid_list = `ps ax | awk '{print $1}'`
            if (pid != nil && pid != "" ) && pid_list =~ /#{pid}/
              Keystone::Base::Logger.instance.warn "pid:#{pid} still running"
              double_process_check_worked = true
              return nil
            else
              if auto_recover
                Keystone::Base::Logger.instance.warn "lock file still exists[pid=#{pid}],but process does not found.auto_recover enabled.so process continues"
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
        Keystone::Base::Logger.instance.error e
        send_error_mail(e,options)
      ensure
        unless double_process_check_worked
          File.delete(pid_file) if double_process_check
        end
        Keystone::Base::Logger.instance.info "finish script (%1.3fsec)" % (Time.now - script_started_at)
      end
    end

    #
    # = エラーメール送信メソッド
    #  エクセプションを何も考えずにメールにて送信する
    # 　各種メール送信属性は定数にて渡す
    #
    # [exception]
    #   エクセプションクラスインスタンス
    #
    def send_error_mail(exception,options)
      if options[:error_mail_to]
        host = Keystone::Os.get()
        title = %|[error][#{host.hostname}][#{exception.message}]|

        mail_to = options[:error_mail_to]
        mail_to = [mail_to] if mail_to.is_a?(String)
        mail_from = options[:error_mail_from] ?  options[:error_mail_from] : mail_to[0]
        smtp_addr = options[:error_mail_smtp_addr]
        smtp_port = options[:error_mail_smtp_port]

        Keystone::Base::Logger.instance.debug "mail_to=#{mail_to}"
        Keystone::Base::Logger.instance.debug "mail_from=#{mail_from}"
        Keystone::Base::Logger.instance.debug "smtp_addr=#{smtp_addr}"
        Keystone::Base::Logger.instance.debug "smtp_port=#{smtp_port}"

        body  = <<-BODY
==== pg ====
        #{File.expand_path($0)}
==== error message ====
        #{exception.message}
====== backtrace ======
        #{exception.backtrace.join("\n")}
===== environment =====
        #{host.dump}
BODY
        Keystone::Mail::Send.sendmail(mail_from,mail_to,title,body,smtp_addr,smtp_port)
      else
        Keystone::Base::Logger.instance.info "ERROR_MAIL_TO not defined.if you want error mail automatically,set this value(check execute() method option)."
      end
    end

  end
end
