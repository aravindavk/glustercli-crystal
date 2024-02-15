require "xml"

require "./helpers"
require "./types"

module GlusterCLI
  class Peer
    # :nodoc:
    def initialize(@cli, @hostname)
    end

    # :nodoc:
    def self.list(cli)
      rc, resp, err = cli.execute_gluster_cmd(["pool", "list", "--xml"])
      if rc != 0
        raise CommandException.new(rc, err)
      end

      document = XML.parse(resp)

      peers = document.xpath_nodes("//peerStatus/peer")

      peers.map do |data|
        peer = NodeInfo.new
        data.children.each do |ele|
          case ele.name
          when "uuid"
            peer.id = ele.content.strip
          when "hostname"
            peer.hostname = ele.content.strip
          when "connected"
            peer.connected = ele.content.strip == "1" ? true : false
          end
        end

        if peer.hostname == "localhost"
          peer.hostname = peer.hostname.gsub(
            "localhost",
            cli.current_hostname
          )
        end

        peer
      end
    end

    # Get a Peer information
    #
    # Example:
    # ```
    # cli.peer("server1.example.com").get
    # ```
    def get
      # TODO: Find a better solution than running Pool list
      # and returning one record
      peers = list(@cli)
      peers.each do |peer|
        return peer if peer.hostname == @hostname
      end

      nil
    end

    # :nodoc:
    def self.add(cli, hostname)
      rc, _resp, err = cli.execute_gluster_cmd(["pool", "probe", hostname, "--xml"])
      if rc != 0
        raise CommandException.new(rc, err)
      end
    end

    # Remove a Peer
    #
    # Example:
    # ```
    # cli.peer("server1.example.com").remove
    # ```
    def remove
      rc, _resp, err = @cli.execute_gluster_cmd(["pool", "detach", @hostname, "--xml"])
      if rc != 0
        raise CommandException.new(rc, err)
      end
    end
  end
end
