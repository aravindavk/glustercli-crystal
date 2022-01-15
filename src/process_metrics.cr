module GlusterCLI
  # :nodoc:
  class ProcessData
    property command, pid = 0, uptime : UInt64 = 0, args = [] of String, pcpu : Float64 = 0, pmem : Float64 = 0

    def initialize(@command : String)
    end

    def self.collect(cmds)
      procs = pid_and_uptime(cmds)
      cpu_and_memory(procs)

      procs
    end

    def self.pid_and_uptime(cmds)
      cmd_args = [
        "--no-header",
        "-ww",
        "-C",
        cmds.join(","),
        "-o", "pid,etimes,comm",
      ]

      # TODO: Handle Error
      _ret, output, _err = GlusterCLI.execute_cmd("ps", cmd_args)
      lines = output.strip.split("\n")

      lines.map do |line|
        parts = line.strip.split

        proc = ProcessData.new(parts[2])
        proc.pid = parts[0].to_i
        proc.uptime = parts[1].to_u64

        content = File.read("/proc/#{proc.pid}/cmdline")
        proc.args = content.strip("\x00").split("\x00")

        proc
      end
    end

    def self.cpu_and_memory(procs)
      pids = [] of Int32
      pids_index = Hash(Int32, ProcessData).new

      procs.each do |proc|
        pids_index[proc.pid] = proc
        pids << proc.pid
      end

      cmd_args = [
        # Batch mode
        "-b",
        # Number of Iterations. Run two iterations to compare with previous
        "-n", "2",
        # Delay time in second(0.2 sec -> 200ms)
        "-d", "0.2",
        # PIDs
        "-p", pids.join(","),
      ]

      _ret, output, _err = GlusterCLI.execute_cmd("top", cmd_args)

      # PID USER      PR  NI    VIRT    RES    SHR S  %CPU  %MEM     TIME+ COMMAND
      lines = output.strip.split("\n")

      collect = false
      metrics = [] of String
      lines.each do |line|
        if line.strip.starts_with?("PID USER")
          collect = true
          metrics = [] of String
        end
        collect = false if line.starts_with?("top - ")

        if collect && !line.strip.starts_with?("PID") && line.strip != ""
          metrics << line.strip
        end
      end

      metrics.each do |line|
        parts = line.split

        proc = pids_index[parts[0].strip.to_i]
        proc.pcpu = parts[8].strip.gsub(",", "").to_f
        proc.pmem = parts[9].strip.gsub(",", "").to_f
      end
    end
  end
end
