module GlusterCLI
  struct VolumeCreateOptions
    property replica_count = 1,
      disperse_count = 0,
      disperse_redundancy_count = 0,
      volume_type = "Distribute",
      force = false
  end

  class Volume
    def initialize(@name : String)
    end

    def info
    end

    def status
    end

    def start(force = false)
    end

    def stop(force = false)
    end

    def option_set(key_values : Array(Array(String, String)))
    end

    def option_set(key : String, value : String)
    end

    def option_reset(keys : Array(String))
    end

    def option_reset(key : String)
    end

    def self.list
    end

    def self.create(name : String, bricks : Array(String), opts : VolumeCreateOptions)
    end

    def self.delete(name : String)
    end
  end
end
