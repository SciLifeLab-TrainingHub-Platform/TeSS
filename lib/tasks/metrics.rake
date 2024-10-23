require 'sys/proctable'

namespace :metrics do
  desc 'Update Prometheus metrics'
  task update: :environment do
    process = Sys::ProcTable.ps(Process.pid)

    # Update memory usage
    MEMORY_GAUGE.set(process.rss * 1024) # rss is in KB, convert to bytes

    # Update CPU usage
    CPU_GAUGE.set(process.pctcpu)
  end
end
