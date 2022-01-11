require "./peer"
require "./volume"
require "./local_metrics"

# Gluster CLI bindings
#
# Create `CLI` instance and execute Gluster commands.
#
# Example:
# ```
# require "glustercli"
#
# cli = GlusterCLI::CLI.new
#
# peers = cli.list_peers
#
# volumes = cli.list_volumes
#
# # List Volumes with realtime status
# volumes = cli.list_volumes(status: true)
# ```
module GlusterCLI
  class CLI
    # :nodoc:
    property gluster_executable, current_hostname : String

    # Instance of Gluster CLI.
    #
    # Example:
    # ```
    # require "glustercli"
    #
    # cli = GlusterCLI::CLI.new
    # puts cli.list_peers
    # ```
    #
    # Set *current_hostname* if it is different from the `hostname`.
    # Gluster pool list command shows "localhost" for the node where
    # the command is run. *current_hostname* will replace the references
    # of the localhost.
    #
    # Example:
    # ```
    # cli = GlusterCLI::CLI.new
    # cli.current_hostname = "server1.example.com"
    # ```
    #
    # Set *gluster_executable* option if Gluster is installed in non-standard
    # location.
    #
    # Example:
    # ```
    # cli = GlusterCLI::CLI.new
    # cli.gluster_executable = "/usr/local/sbin/gluster"
    # ```
    def initialize
      @gluster_executable = "gluster"
      @current_hostname = `hostname`.strip
    end

    # List all peers of the Cluster
    #
    # Example:
    # ```
    # puts cli.list_peers
    # ```
    def list_peers
      Peer.list(self)
    end

    # Add new peer to the Cluster
    #
    # Example:
    # ```
    # cli.add_peer("server2.example.com")
    # ```
    def add_peer(hostname : String)
      Peer.add(self, hostname)
    end

    # Get the Peer Object
    #
    # Example:
    # ```
    # peer = cli.peer("server1.example.com")
    # peer.remove
    # ```
    def peer(hostname : String)
      Peer.new(self, hostname)
    end

    # List all Volumes of the Cluster
    #
    # Example:
    # ```
    # puts cli.list_volumes
    #
    # # List all Volumes with realtime status
    # puts cli.list_volumes(status: true)
    # ```
    def list_volumes(status = false)
      Volume.list(self, status)
    end

    # Create a new Gluster Volume
    #
    # Example:
    # ```
    # opts = VolumeCreateOptions.new
    # opts.replica_count = 3
    #
    # bricks = [
    #   "server1.example.com:/bricks/gvol1/brick1/brick",
    #   "server2.example.com:/bricks/gvol1/brick2/brick",
    #   "server3.example.com:/bricks/gvol1/brick3/brick",
    # ]
    # cli.create_volume("gvol1", bricks, opts)
    # ```
    def create_volume(name : String, bricks : Array(String), opts : VolumeCreateOptions)
      Volume.create(self, name, bricks, opts)
    end

    # Get the Volume Object
    #
    # Example:
    # ```
    # volume = cli.volume("gvol1")
    # volume.start
    # ```
    def volume(name : String) : Volume
      Volume.new(self, name)
    end

    # Collect the Local metrics
    #
    # Example:
    # ```
    # cli = GlusterCLI::CLI.new
    # cli.local_metrics
    # cli.local_metrics(log_dir: "/var/log/glusterfs")
    # ```
    def local_metrics(log_dir = "/var/log/glusterfs")
      LocalMetrics.collect(log_dir)
    end
  end
end
