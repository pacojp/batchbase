class BatchTooLong < Batchbase::LogFormatter
  include Batchbase::Core
  skip_logging

  TEST_FILE = '/tmp/.batchbase_batch.txt'

  def proceed(opt={})
    @shutdown = false
    execute(opt) do
      100.times do
        sleep 1
        if @shutdown
          break
        end
      end
    end
  end

  def receive_signal(sig)
    @shutdown = sig
  end
end
