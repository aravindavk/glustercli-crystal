require "xml"

require "./helpers"

module GlusterCLI
  class Peer
    property id = "",
      hostname = "",
      connected = false

    def initialize
    end

    def self.list
      rc, resp = execute_cmd("gluster",
        ["pool", "list", "--xml"])
      # TODO: Log error if rc != 0
      return [] of Peer if rc != 0

      document = XML.parse(resp)

      prs = document.xpath_nodes("//peerStatus/peer")

      prs.map do |pr|
        peer = Peer.new
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
