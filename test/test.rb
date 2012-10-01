# -*- coding: utf-8 -*-

$: << File.dirname(__FILE__)
require 'test_helper'
require 'test/unit'
require 'Fileutils'

require 'batch'

class TestBatchbase < Test::Unit::TestCase

  PID_FILE_FORCE = '/tmp/.batchbase_test.pid'

  def setup
    File.delete(pid_file) if File.exist?(pid_file)
    File.delete(PID_FILE_FORCE) if File.exist?(PID_FILE_FORCE)
  end

  def pid_file
    b = Batch.new
    b.send(:init)
    b.send(:parse_options,{},[])
    b.env[:pid_file]
  end

  def test_pid_file
    b = Batch.new
    b.send(:init)
    b.send(:parse_options,{},[])
    b.send(:double_process_check_and_create_pid_file)
    assert_equal true,File.exists?(b.env[:pid_file])
    b.send(:release)
    assert_equal false,File.exists?(b.env[:pid_file])
  end

  def test_there_was_lock_file
    FileUtils.touch(pid_file) # すでにpid_fileがあるとして
    b = Batch.new
    b.send(:init)
    b.send(:parse_options,{},[])
    result = b.send(:double_process_check_and_create_pid_file)
    assert_equal Batchbase::Core::DOUBLE_PROCESS_CHECK__NG,result
    File.delete(pid_file)
  end

  def test_there_was_lock_file_but_not_double_cheking
    FileUtils.touch(pid_file) # すでにpid_fileがあるとして
    b = Batch.new
    b.send(:init)
    b.send(:parse_options,{:double_process_check=>false},[])
    result = b.send(:double_process_check_and_create_pid_file)
    assert_equal Batchbase::Core::DOUBLE_PROCESS_CHECK__OK,result
    File.delete(pid_file)
  end

  def test_auto_recover
    FileUtils.touch(pid_file) # すでにpid_fileがあるとして
    b = Batch.new
    b.send(:init)
    b.send(:parse_options,{:auto_recover=>true},[])
    result = b.send(:double_process_check_and_create_pid_file)
    assert_equal Batchbase::Core::DOUBLE_PROCESS_CHECK__AUTO_RECOVER,result
    assert_equal true,File.exists?(b.env[:pid_file]) # pid_fileは存在していないとだめ
    File.delete(pid_file)
  end

  def test_auto_recover
    b = Batch.new
    b.send(:init)
    b.send(:parse_options,{},[:auto_recover=>true])
    b.send(:double_process_check_and_create_pid_file)
    assert_equal true,File.exists?(b.env[:pid_file])
    b.send(:release)
    assert_equal false,File.exists?(b.env[:pid_file])
  end

  def test_option_parser
    # ぎゃくにかいてもーた、、、、
    b = Batch.new
    b.send(:init)
    argv = []
    b.send(:parse_options,{},argv)
    assert_equal b.env[:environment],'development'
    assert_equal b.env[:double_process_check],true
    assert_equal b.env[:auto_recover],false
    assert_equal b.env[:pg_name],'test.rb'

    b = Batch.new
    b.send(:init)
    argv = ['-e','test','--auto_recover']
    b.send(:parse_options,{},argv)
    assert_equal b.env[:environment],'test'
    assert_equal b.env[:double_process_check],true
    assert_equal b.env[:auto_recover],true

    b = Batch.new
    b.send(:init)
    argv = ['--double_process_check_off']
    b.send(:parse_options,{},argv)
    assert_equal b.env[:double_process_check],false

    # オートリカバリー入れたらダブルプロセスチェックは強制ON
    b = Batch.new
    b.send(:init)
    argv = ['-e','test','--auto_recover','double_process_check_off']
    b.send(:parse_options,{},argv)
    assert_equal b.env[:environment],'test'
    assert_equal b.env[:double_process_check],true
    assert_equal b.env[:auto_recover],true

    b = Batch.new
    b.send(:init)
    argv = ['--lockfile','/tmp/.lockfile_test']
    b.send(:parse_options,{},argv)
    assert_equal b.env[:pid_file],'/tmp/.lockfile_test'
  end

  def test_options
    # ぎゃくにかいてもーた、、、、
    b = Batch.new
    b.send(:init)
    argv = []
    options = {:double_process_check=>false,:environment=>'test'}
    b.send(:parse_options,options,argv)
    assert_equal b.env[:environment],'test'
    assert_equal b.env[:double_process_check],false
    assert_equal b.env[:auto_recover],false
    assert_equal b.env[:pg_name],'test.rb'

    # オートリカバリー入れたらダブルプロセスチェックは強制ON
    b = Batch.new
    b.send(:init)
    argv = []
    options = {:double_process_check=>false,:auto_recover=>true}
    b.send(:parse_options,options,argv)
    assert_equal b.env[:double_process_check],true
    assert_equal b.env[:auto_recover],true

    b = Batch.new
    b.send(:init)
    argv = []
    options = {:pid_file=>'/tmp/.lock_test'}
    b.send(:parse_options,options,argv)
    assert_equal b.env[:pid_file],'/tmp/.lock_test'

    # ミックスならARGVの指定の方を優先
    b = Batch.new
    b.send(:init)
    argv = ['--lockfile','/tmp/.lllock','--auto_recover']
    options = {:pid_file=>'/tmp/.lock_test',:auto_recover=>false,:double_process_check=>false}
    b.send(:parse_options,options,argv)
    assert_equal b.env[:double_process_check],true
    assert_equal b.env[:auto_recover],true
    assert_equal b.env[:pid_file],'/tmp/.lllock'
  end

  def test_options_plus
    b = Batch.new
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

  def test_prosess_still_exists
    # 取り敢えずこのテスの際は無駄なファイルを消すよ

    pid = fork do
      b = Batch.new
      b.proceed(:pid_file=>PID_FILE_FORCE)
    end

    sleep 1

    b2 = Batch.new
    b2.send(:init)
    b2.send(:parse_options,{:pid_file=>PID_FILE_FORCE},[])
    result = b2.send(:double_process_check_and_create_pid_file)
    assert_equal Batch::DOUBLE_PROCESS_CHECK__STILL_RUNNING,result
    #b2.send(:execute_inner)
    b2.send(:release)
    assert_equal true,File.exists?(b2.env[:pid_file]) # pid_fileまだは存在していないとだめ
    sleep 3
  end
end
