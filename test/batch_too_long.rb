class BatchTooLong < Batchbase::LogFormatter
  include Batchbase::Core

  def proceed(opt={})
    unless opt[:not_set_observer]
      if opt[:signal_cancel]
        set_signal_observer(:ignore_signal)
      else
        set_signal_observer(:receive_signal)
      end
    end
    @shutdown = false
    execute(opt) do
      100.times do
        sleep 1
        break if @shutdown
      end
    end
  end

  def receive_signal(sig)
    @shutdown = true
  end

  def ignore_signal(sig)
  end
end
