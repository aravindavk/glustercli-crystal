require "json"

require "./process_metrics"

module GlusterCLI
  PROCESS_GLUSTERD   = "glusterd"
  PROCESS_GLUSTERFSD = "glusterfsd"
  PROCESS_GLUSTERFS  = "glusterfs"
  PROCESS_EXPORTER   = "gluster-metrics-exporter"
  PROCESS_SHD        = "glustershd"

  struct ProcessMetric
    include JSON::Serializable

    property cpu_percentage = 0.0,
      memory_percentage = 0.0,
      uptime_seconds : UInt64 = 0

    def initialize
    end
  end

  class LocalMetrics
    include JSON::Serializable

    property bricks = Hash(String, ProcessMetric).new,
      glusterd = ProcessMetric.new,
      shds = [] of ProcessMetric,
      log_dir_size_bytes : UInt64 = 0,
      node_uptime_seconds : UInt64 = 0,
      exporter = ProcessMetric.new

    def initialize
    end

    # :nodoc:
    def self.node_uptime
      File.read("/proc/uptime").strip.split[0].split(".")[0].to_u64
    end

    # :nodoc:
    def self.dir_size(dir)
      # TODO: Handle Error
      _ret, output, _err = GlusterCLI.execute_cmd("du", ["-s", dir])

      output.strip.split[0].to_u64
    end

    # :nodoc:
    def self.brick_metrics(process)
      brick = ProcessMetric.new
      pick_next_arg = false
      brick_path = ""
      process.args.each do |arg|
        if pick_next_arg
          brick_path = arg
          brick.cpu_percentage = process.pcpu
          brick.memory_percentage = process.pmem
          brick.uptime_seconds = process.uptime
          break
        end
        pick_next_arg = true if arg == "--brick-name"
      end

      {brick_path => brick}
    end

    # :nodoc:
    def self.glusterd_metrics(process)
      gd = ProcessMetric.new
      gd.cpu_percentage = process.pcpu
      gd.memory_percentage = process.pmem
      gd.uptime_seconds = process.uptime

      gd
    end

    # :nodoc:
    def self.exporter_metrics(process)
      exporter = ProcessMetric.new
      exporter.cpu_percentage = process.pcpu
      exporter.memory_percentage = process.pmem
      exporter.uptime_seconds = process.uptime

      exporter
    end

    # :nodoc:
    def self.shd_metrics(process)
      shd = ProcessMetric.new
      shd.cpu_percentage = process.pcpu
      shd.memory_percentage = process.pmem
      shd.uptime_seconds = process.uptime

      shd
    end

    # :nodoc:
    def self.shd_process?(process)
      pick_next_arg = false
      proc_name = ""
      process.args.each do |arg|
        if pick_next_arg
          proc_name = arg
          break
        end

        pick_next_arg = true if arg == "--process-name"
      end

      proc_name == PROCESS_SHD
    end

    # :nodoc:
    def self.collect(log_dir)
      procs = ProcessData.collect([PROCESS_GLUSTERD, PROCESS_GLUSTERFSD, PROCESS_GLUSTERFS, PROCESS_EXPORTER])
      local_metrics = LocalMetrics.new
      local_metrics.node_uptime_seconds = node_uptime
      # TODO: Handle custom log directory
      local_metrics.log_dir_size_bytes = dir_size(log_dir)

      procs.each do |prc|
        if prc.command == PROCESS_GLUSTERFSD
          local_metrics.bricks.merge!(brick_metrics(prc))
        elsif prc.command == PROCESS_GLUSTERD
          local_metrics.glusterd = glusterd_metrics(prc)
        elsif prc.command == PROCESS_EXPORTER
          local_metrics.exporter = exporter_metrics(prc)
        elsif prc.command == PROCESS_GLUSTERFS
          if shd_process?(prc)
            local_metrics.shds << shd_metrics(prc)
          end
        end
      end

      local_metrics
    end
  end
end
