class Batch < Batchbase::LogFormatter
  include Batchbase::Core
  skip_logging

  def proceed(opt={})
    execute(opt) do
      sleep 3
      11
    end
  end
end
