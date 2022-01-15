module GlusterCLI
  # :nodoc:
  def self.execute_cmd(cmd, args)
    stdout = IO::Memory.new
    stderr = IO::Memory.new
    # Set numeric locale to en_US.utf8 to avoid all
    # float conversion issues
    status = Process.run(cmd, args: args, output: stdout, error: stderr,
      env: {"LC_NUMERIC" => "en_US.utf8"})
    {status.exit_code, stdout.to_s, stderr.to_s}
  end

  class CLI
    # :nodoc:
    def execute_gluster_cmd(args)
      GlusterCLI.execute_cmd(@gluster_executable, args)
    end
  end
end
