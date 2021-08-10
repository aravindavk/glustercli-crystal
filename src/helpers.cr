module GlusterCLI
  # :nodoc:
  def self.execute_cmd(cmd, args)
    stdout = IO::Memory.new
    stderr = IO::Memory.new
    status = Process.run(cmd, args: args, output: stdout, error: stderr)
    {status.exit_code, stdout.to_s, stderr.to_s}
  end

  class CLI
    # :nodoc:
    def execute_gluster_cmd(args)
      GlusterCLI.execute_cmd(@gluster_executable, args)
    end
  end
end
