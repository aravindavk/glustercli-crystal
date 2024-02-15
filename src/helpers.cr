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
      rc, resp, err = GlusterCLI.execute_cmd(@gluster_executable, args)
      err_resp = GlusterCLI.parse_error(resp)
      unless err_resp.ok?
        raise CommandException.new(err_resp.ret, err_resp.message, err_resp.errno)
      end

      if rc != 0
        raise CommandException.new(rc, err)
      end

      resp
    end
  end

  def self.parse_error(data)
    err = CliError.new
    document = XML.parse(data)
    errdoc = document.first_element_child

    return err if errdoc.nil?

    errdoc.children.each do |ele|
      case ele.name
      when "opRet"
        err.ret = ele.content.strip.to_i
      when "opErrno"
        err.errno = ele.content.strip.to_i
      when "opErrstr"
        err.message = ele.content.strip
      end
    end

    err.ok = false if err.message != ""

    err
  end
end
