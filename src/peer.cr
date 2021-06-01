require "xml"

require "./helpers"
require "./types"

module GlusterCLI
  class Peer
    def initialize
    end

    def self.list
      rc, resp, err = GlusterCLI.execute_gluster_cmd(["pool", "list", "--xml"])
      if rc != 0
        raise CommandException.new(rc, err)
      end

      document = XML.parse(resp)

      prs = document.xpath_nodes("//peerStatus/peer")

      prs.map do |pr|
        peer = NodeInfo.new
        pr.children.each do |ele|
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
            GlusterCLI.current_hostname
          )
        end

        peer
      end
    end

    def self.probe
    end

    def self.detach
    end
  end
end
