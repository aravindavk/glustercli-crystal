require "json"

module GlusterCLI
  HEALTH_UP       = "Up"
  HEALTH_DOWN     = "Down"
  HEALTH_PARTIAL  = "Partial"
  HEALTH_DEGRADED = "Degraded"

  STATE_CREATED = "Created"
  STATE_STARTED = "Started"
  STATE_STOPPED = "Stopped"

  TYPE_REPLICATE = "Replicate"
  TYPE_DISPERSE  = "Disperse"

  class CommandException < Exception
    def initialize(@ret : Int32, @error : String)
      super("[#{ret}] #{error}")
    end
  end

  struct VolumeCreateOptions
    property replica_count = 1,
      disperse_count = 0,
      disperse_redundancy_count = 0,
      volume_type = "Distribute",
      force = false
  end

  struct NodeInfo
    include JSON::Serializable

    property id = "",
      hostname = "",
      connected = false

    def initialize
    end
  end

  struct Brick
    include JSON::Serializable

    property node = NodeInfo.new,
      path = "",
      type = "",
      state = "",
      pid = 0,
      size_total : UInt64 = 0,
      size_free : UInt64 = 0,
      inodes_total : UInt64 = 0,
      inodes_free : UInt64 = 0,
      size_used : UInt64 = 0,
      inodes_used : UInt64 = 0,
      device = "",
      block_size = 0,
      fs_name = "",
      mnt_options = ""

    def initialize
    end
  end

  struct Subvolume
    include JSON::Serializable

    property type = "",
      health = "",
      replica_count = 0,
      disperse_count = 0,
      disperse_redundancy_count = 0,
      arbiter_count = 0,
      size_total : UInt64 = 0,
      size_free : UInt64 = 0,
      inodes_total : UInt64 = 0,
      inodes_free : UInt64 = 0,
      size_used : UInt64 = 0,
      inodes_used : UInt64 = 0,
      up_bricks = 0,
      bricks = [] of Brick

    def initialize
    end
  end

  struct VolumeInfo
    include JSON::Serializable

    property name = "",
      id = "",
      state = "",
      snapshot_count = 0,
      brick_count = 0,
      distribute_count = 0,
      replica_count = 0,
      arbiter_count = 0,
      disperse_count = 0,
      disperse_redundancy_count = 0,
      type = "",
      health = "",
      transport = "",
      size_total : UInt64 = 0,
      size_free : UInt64 = 0,
      inodes_total : UInt64 = 0,
      inodes_free : UInt64 = 0,
      size_used : UInt64 = 0,
      inodes_used : UInt64 = 0,
      up_subvols = 0,
      subvols = [] of Subvolume,
      options = {} of String => String

    @[JSON::Field(ignore: true)]
    property bricks = [] of Brick

    def initialize
    end

    def subvol_type
      # "Distributed Replicate" will become "Replicate"
      @type.split(" ")[-1]
    end

    def subvol_size
      if @replica_count > 1
        @replica_count
      elsif @disperse_count > 0
        @disperse_count
      else
        1
      end
    end
  end
end
