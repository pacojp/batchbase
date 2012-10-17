class BatchByHand
  include Batchbase::Core
  skip_logging

  TEST_FILE = '/tmp/.batchbase_batch_by_hand.txt'

  def proceed(opt={})
    @shutdown = false
    set_signal_observer(:receive_signal)

    execute(opt) do
      sleep 20
      File.write(TEST_FILE,$$)
      if opt[:daemonize]
        loop do
          sleep 1
          if @shutdown
            #puts "shutdown by #{@shutdown}"
            break
          end
        end
      end
      11
    end
  end

  def receive_signal(sig)
    @shutdown = sig
  end
end
