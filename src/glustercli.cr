require "./peer"
require "./volume"

module GlusterCLI
  class CLI
    property gluster_executable, current_hostname : String

    def initialize
      @gluster_executable = "gluster"
      @current_hostname = `hostname`.strip
    end

    def list_peers
      Peer.list(self)
    end

    def add_peer(hostname : String)
      Peer.add(self, hostname)
    end

    def peer(hostname : String)
      Peer.new(self, hostname)
    end

    def list_volumes(status = false)
      Volume.list(self, status)
    end

    def create_volume(name : String, bricks : Array(String), opts : VolumeCreateOptions)
      Volume.create(self, name, bricks, opts)
    end

    def volume(name : String)
      Volume.new(self, name)
    end
  end
end
