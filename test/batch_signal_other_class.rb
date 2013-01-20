class BatchSignalOtherClass
  include Batchbase::Core
  skip_logging

  def initialize
  end

  TEST_FILE = '/tmp/.batchbase_batch.txt'

  def proceed(opt={})
    @shutdown = false
    sc = SomeClass.new
    set_signal_observer(:r_sig,sc)
    set_signal_observer(:receive_signal)

    execute(opt) do
      sleep 4
    end
  end
end

class SomeClass
  RECEIVE_SIGNAL_FILE = '/tmp/.batchbase_test.receive_signal.pid'
  def r_sig(sig)
    File.write(RECEIVE_SIGNAL_FILE,$$)
  end
end
