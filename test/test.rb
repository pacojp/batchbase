# -*- coding: utf-8 -*-

$: << File.dirname(__FILE__)
require 'test_helper'
require 'test/unit'
require 'Fileutils'

require 'sys/proctable'

require 'batch'
require 'batch_too_long'

class TestBatchbase < Test::Unit::TestCase

  PID_FILE_FORCE = '/tmp/.batchbase_test.pid'
  PID_FILE_DAEMONIZE_TEST = '/tmp/.batchbase_daemonize_test.pid'

  def setup
    delete_file(pid_file)
    delete_file(PID_FILE_FORCE)
    delete_file(PID_FILE_DAEMONIZE_TEST)
    delete_file(Batch::TEST_FILE)
  end

  def new_batch_instance
    b = Batch.new
    b.skip_logging
    b
  end

  def delete_file(file)
    File.delete(file) if File.exist?(file)
  end

  def pid_file
    b = new_batch_instance
    b.send(:init)
    b.send(:parse_options,{},[])
    b.env[:pid_file]
  end

  def test_pid_file
    b = new_batch_instance
    b.send(:init)
    b.send(:parse_options,{},[])
    b.send(:double_process_check_and_create_pid_file)
    assert_equal true,File.exists?(b.env[:pid_file])
    b.send(:release)
    assert_equal false,File.exists?(b.env[:pid_file])
  end

  def test_there_was_lock_file
    FileUtils.touch(pid_file) # すでにpid_fileがあるとして
    b = new_batch_instance
    b.send(:init)
    b.send(:parse_options,{},[])
    result = b.send(:double_process_check_and_create_pid_file)
    assert_equal Batchbase::Core::DOUBLE_PROCESS_CHECK__NG,result
    File.delete(pid_file)
  end

  def test_there_was_lock_file_but_not_double_cheking
    FileUtils.touch(pid_file) # すでにpid_fileがあるとして
    b = new_batch_instance
    b.send(:init)
    b.send(:parse_options,{:double_process_check=>false},[])
    result = b.send(:double_process_check_and_create_pid_file)
    assert_equal Batchbase::Core::DOUBLE_PROCESS_CHECK__OK,result
    File.delete(pid_file)
  end

  def test_auto_recover
    FileUtils.touch(pid_file) # すでにpid_fileがあるとして
    b = new_batch_instance
    b.send(:init)
    b.send(:parse_options,{:auto_recover=>true},[])
    result = b.send(:double_process_check_and_create_pid_file)
    assert_equal Batchbase::Core::DOUBLE_PROCESS_CHECK__AUTO_RECOVER,result
    assert_equal true,File.exists?(b.env[:pid_file]) # pid_fileは存在していないとだめ
    File.delete(pid_file)
  end

  def test_auto_recover
    b = new_batch_instance
    b.send(:init)
    b.send(:parse_options,{},[:auto_recover=>true])
    b.send(:double_process_check_and_create_pid_file)
    assert_equal true,File.exists?(b.env[:pid_file])
    b.send(:release)
    assert_equal false,File.exists?(b.env[:pid_file])
  end

  def test_option_parser
    # ぎゃくにかいてもーた、、、、
    b = new_batch_instance
    b.send(:init)
    argv = []
    b.send(:parse_options,{},argv)
    assert_equal b.env[:environment],'development'
    assert_equal b.env[:double_process_check],true
    assert_equal b.env[:auto_recover],false
    assert_equal b.env[:pg_name],'test.rb'

    b = new_batch_instance
    b.send(:init)
    argv = ['-e','test','--auto_recover']
    b.send(:parse_options,{},argv)
    assert_equal b.env[:environment],'test'
    assert_equal b.env[:double_process_check],true
    assert_equal b.env[:auto_recover],true

    b = new_batch_instance
    b.send(:init)
    argv = ['--double_process_check_off']
    b.send(:parse_options,{},argv)
    assert_equal b.env[:double_process_check],false

    # オートリカバリー入れたらダブルプロセスチェックは強制ON
    b = new_batch_instance
    b.send(:init)
    argv = ['-e','test','--auto_recover','double_process_check_off']
    b.send(:parse_options,{},argv)
    assert_equal b.env[:environment],'test'
    assert_equal b.env[:double_process_check],true
    assert_equal b.env[:auto_recover],true

    b = new_batch_instance
    b.send(:init)
    argv = ['--lockfile','/tmp/.lockfile_test']
    b.send(:parse_options,{},argv)
    assert_equal b.env[:pid_file],'/tmp/.lockfile_test'
  end

  def test_options
    # ぎゃくにかいてもーた、、、、
    b = new_batch_instance
    b.send(:init)
    argv = []
    options = {:double_process_check=>false,:environment=>'test'}
    b.send(:parse_options,options,argv)
    assert_equal b.env[:environment],'test'
    assert_equal b.env[:double_process_check],false
    assert_equal b.env[:auto_recover],false
    assert_equal b.env[:pg_name],'test.rb'

    # オートリカバリー入れたらダブルプロセスチェックは強制ON
    b = new_batch_instance
    b.send(:init)
    argv = []
    options = {:double_process_check=>false,:auto_recover=>true}
    b.send(:parse_options,options,argv)
    assert_equal b.env[:double_process_check],true
    assert_equal b.env[:auto_recover],true

    b = new_batch_instance
    b.send(:init)
    argv = []
    options = {:pid_file=>'/tmp/.lock_test'}
    b.send(:parse_options,options,argv)
    assert_equal b.env[:pid_file],'/tmp/.lock_test'

    # ミックスならARGVの指定の方を優先
    b = new_batch_instance
    b.send(:init)
    argv = ['--lockfile','/tmp/.lllock','--auto_recover']
    options = {:pid_file=>'/tmp/.lock_test',:auto_recover=>false,:double_process_check=>false}
    b.send(:parse_options,options,argv)
    assert_equal b.env[:double_process_check],true
    assert_equal b.env[:auto_recover],true
    assert_equal b.env[:pid_file],'/tmp/.lllock'
  end

  def test_options_plus
    b = new_batch_instance
    opts = b.option_parser
    opts.on("-f", "--favorite_number=value",
      Integer,"your favorite number"
      ) do |v|
      b.env[:favorite_number] = v
    end

    b.send(:init)
    argv = ['--favorite_number','11']
    b.send(:parse_options,{},argv)
    assert_equal 'development',b.env[:environment]
    assert_equal true,b.env[:double_process_check]
    assert_equal false,b.env[:auto_recover]
    assert_equal 'test.rb',b.env[:pg_name]
    assert_equal 11,b.env[:favorite_number]
  end

  def test_deamonize
    b = new_batch_instance
    pid = fork do
      b.proceed(:daemonize=>true,:pid_file=>PID_FILE_DAEMONIZE_TEST)
    end

    sleep 1
    #
    # デーモン化すると
    # ・pidが変わる
    # ・ppidが1になるk
    #
    pid_new = File.read(PID_FILE_DAEMONIZE_TEST).chomp.to_i
    assert_not_equal pid,pid_new
    daemon_process = Sys::ProcTable.ps(pid_new)
    assert_equal 1,daemon_process.ppid
    sleep 3
    assert_equal true,Batch.is_there_process(pid_new)
    assert_equal pid_new,File.read(Batch::TEST_FILE).chomp.to_i
    # シグナルを送る
    # pid_fileを消して終了するか？
    `kill #{pid_new}`
    sleep 3
    assert_equal false,Batch.is_there_process(pid_new)
    assert_equal false,File.exists?(PID_FILE_DAEMONIZE_TEST)
  end

  def test_is_there_process
    assert_equal true,Batch.is_there_process($$)
    assert_equal false,Batch.is_there_process(1111111111)
  end

  def test_signal
    assert_equal false,File.exists?(PID_FILE_FORCE)
    pid = fork do
      b = BatchTooLong.new
      b.skip_logging
      b.proceed(:pid_file=>PID_FILE_FORCE)
    end
    sleep 3
    pid_by_file = File.read(PID_FILE_FORCE).chomp.to_i
    assert_equal true,Batch.is_there_process(pid)
    assert_equal pid,pid_by_file
    # シグナルを送る
    # pid_fileを消して終了するか？
    `kill #{pid}`
    sleep 3
    assert_equal false,Batch.is_there_process(pid)
    assert_equal false,File.exists?(PID_FILE_FORCE)
  end

  # すでにバッチ起動＆プロセスがまだ存在する場合のテスト
  def test_prosess_still_exists
    pid = fork do
      b = new_batch_instance
      b.proceed(:pid_file=>PID_FILE_FORCE)
    end

    sleep 1

    b2 = new_batch_instance
    b2.send(:init)
    b2.send(:parse_options,{:pid_file=>PID_FILE_FORCE},[])
    result = b2.send(:double_process_check_and_create_pid_file)
    assert_equal Batch::DOUBLE_PROCESS_CHECK__STILL_RUNNING,result
    #b2.send(:execute_inner)
    b2.send(:release)
    assert_equal true,File.exists?(b2.env[:pid_file]) # pid_fileまだは存在していないとだめ
    sleep 3
  end

  #
  # HACKME
  # executeを読んだ際のメッセージ文言等でエラーが出る場合のフック、、、
  # 実際はexecuteをシュミレートしたテストしかしていない＆log出力も
  # 切ってるので、、、、、、
  #
end
