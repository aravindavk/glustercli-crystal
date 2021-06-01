require "./peer"
require "./volume"

module GlusterCLI
  @@gluster_executable = "gluster"
  @@current_hostname = `hostname`.strip

  def self.gluster_executable=(gluster_path : String)
    @@gluster_executable = gluster_path
  end

  def self.gluster_executable
    @@gluster_executable
  end

  def self.current_hostname=(hostname : String)
    @@current_hostname = hostname
  end

  def self.current_hostname
    @@current_hostname
  end

  def self.list_peers
    Peer.list
  end

  def self.add_peer(hostname : String)
    Peer.add(hostname)
  end

  def self.remove_peer(hostname : String)
    Peer.remove(hostname)
  end

  def self.list_volumes
    Volume.list
  end

  def self.list_volume_status
    Volume.status
  end

  def self.create_volume(name : String, bricks : Array(String), opts : VolumeCreateOptions)
    Volume.create(name, bricks, opts)
  end

  def self.delete_volume(name : String)
    Volume.delete(name)
  end

  def self.volume(name : String)
    Volume.new(name)
  end
end
