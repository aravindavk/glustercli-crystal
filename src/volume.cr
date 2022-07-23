require "./types"

module GlusterCLI
  class Volume
    # :nodoc:
    def initialize(@cli : CLI, @name : String)
    end

    # :nodoc:
    def self.group_subvols(volumes)
      volumes.map do |volume|
        subvol_type = volume.subvol_type

        # Divide the bricks list as subvolumes
        subvol_bricks = [] of Array(Brick)
        volume.bricks.each_slice(volume.subvol_size.to_i) do |grp|
          subvol_bricks << grp
        end

        volume.subvols = (0...volume.distribute_count).map do |sidx|
          subvol = Subvolume.new
          subvol.type = subvol_type
          subvol.replica_count = volume.replica_count
          subvol.disperse_count = volume.disperse_count
          subvol.disperse_redundancy_count = volume.disperse_redundancy_count
          subvol.bricks = subvol_bricks[sidx]

          subvol
        end

        # Remove default Bricks list
        volume.bricks = [] of Brick

        volume
      end
    end

    # :nodoc:
    # TODO: Fix and remove this warning
    # ameba:disable Metrics/CyclomaticComplexity
    def self.parse_info(document)
      vols = document.xpath_nodes("//volume")

      vols.map do |vol|
        volume = VolumeInfo.new
        vol.children.each do |ele|
          case ele.name
          when "name"
            volume.name = ele.content.strip
          when "id"
            volume.id = ele.content.strip
          when "statusStr"
            volume.state = ele.content.strip
          when "typeStr"
            volume.type = ele.content.strip
          when "transport"
            volume.transport = "tcp" if ele.content.strip == "0"
          when "snapshotCount"
            volume.snapshot_count = ele.content.strip.to_i
          when "brickCount"
            volume.brick_count = ele.content.strip.to_i
          when "replicaCount"
            volume.replica_count = ele.content.strip.to_i
          when "arbiterCount"
            volume.arbiter_count = ele.content.strip.to_i
          when "disperseCount"
            volume.disperse_count = ele.content.strip.to_i
          when "redundancyCount"
            volume.disperse_redundancy_count = ele.content.strip.to_i
          else
            nil
          end
        end
        volume.distribute_count = (volume.brick_count / volume.subvol_size).to_i

        brks = vol.xpath_nodes(".//brick")
        brks.each do |brk|
          brick = Brick.new
          brk.children.each do |bele|
            case bele.name
            when "name"
              parts = bele.content.strip.split(":")
              brick.node.hostname = parts[0...-1].join(":")
              brick.path = parts[-1]
            when "hostUuid"
              brick.node.id = bele.content.strip
            when "isArbiter"
              brick.type = bele.content.strip == '1' ? "Arbiter" : "Brick"
            end
          end
          volume.bricks << brick
        end

        opts = vol.xpath_nodes(".//option")
        opts.each do |opt|
          optname = ""
          optvalue = ""
          opt.children.each do |oele|
            case oele.name
            when "name"
              optname = oele.content.strip
            when "value"
              optvalue = oele.content.strip
            end
          end
          volume.options[optname] = optvalue
        end

        volume
      end
    end

    # Get Volume info and realtime Status
    #
    # Example:
    # ```
    # cli.volume("gvol1").info
    # cli.volume("gvol1").info(status: true)
    # ```
    def info(status = false) : VolumeInfo
      return _status if status

      rc, resp, err = @cli.execute_gluster_cmd(["volume", "info", @name, "--xml"])
      if rc != 0
        raise CommandException.new(rc, err)
      end

      document = XML.parse(resp)

      vols = Volume.group_subvols(Volume.parse_info(document))

      raise CommandException.new(-1, "Invalid Volume name") if vols.size == 0

      vols[0]
    end

    # :nodoc:
    def self.list(cli, status = false)
      return all_status(cli) if status

      rc, resp, err = cli.execute_gluster_cmd(["volume", "info", "--xml"])
      if rc != 0
        raise CommandException.new(rc, err)
      end

      document = XML.parse(resp)

      group_subvols(parse_info(document))
    end

    # :nodoc:
    # TODO: Fix and remove this warning
    # ameba:disable Metrics/CyclomaticComplexity
    def self.brick_status(cli, volname = "all")
      # TODO: Volume filter
      rc, resp, err = cli.execute_gluster_cmd(["volume", "status", volname, "detail", "--xml"])
      if rc != 0
        raise CommandException.new(rc, err)
      end

      document = XML.parse(resp)

      bricks_data = document.xpath_nodes("//volStatus/volumes/volume/node")

      bricks_data.map do |brk|
        brick = Brick.new
        brk.children.each do |ele|
          case ele.name
          when "hostname"
            brick.node.hostname = ele.content.strip
          when "path"
            brick.path = ele.content.strip
          when "peerid"
            brick.node.id = ele.content.strip
          when "status"
            brick.state = ele.content.strip == "1" ? HEALTH_UP : HEALTH_DOWN
          when "pid"
            brick.pid = ele.content.strip.to_i
          when "sizeTotal"
            brick.size_total = ele.content.strip.to_u64
          when "sizeFree"
            brick.size_free = ele.content.strip.to_u64
          when "inodesTotal"
            brick.inodes_total = ele.content.strip.to_u64
          when "inodesFree"
            brick.inodes_free = ele.content.strip.to_u64
          when "device"
            brick.device = ele.content.strip
          when "blockSize"
            brick.block_size = ele.content.strip.to_i
          when "fsName"
            brick.fs_name = ele.content.strip
          when "mntOptions"
            brick.mnt_options = ele.content.strip
          end
        end

        brick.size_used = brick.size_total - brick.size_free
        brick.inodes_used = brick.inodes_total - brick.inodes_free

        brick
      end
    end

    # :nodoc:
    def self.update_brick_status(volumes, bricks_status)
      # Update each brick's status from Volume status output

      # Create hashmap of Bricks data so that it
      # helps to lookup later.
      tmp_brick_status = {} of String => Brick
      bricks_status.each do |brick|
        tmp_brick_status["#{brick.node.hostname}:#{brick.path}"] = brick
      end

      volumes.map do |volume|
        volume.subvols = volume.subvols.map do |subvol|
          subvol.bricks = subvol.bricks.map do |brick|
            # Update brick status info if volume status output
            # contains respective brick info. Sometimes volume
            # status skips brick entries if glusterd of respective
            # node is not reachable or down(Offline).
            data = tmp_brick_status["#{brick.node.hostname}:#{brick.path}"]?
            if !data.nil?
              brick.state = data.state
              brick.pid = data.pid
              brick.size_total = data.size_total
              brick.size_free = data.size_free
              brick.size_used = data.size_used
              brick.inodes_total = data.inodes_total
              brick.inodes_free = data.inodes_free
              brick.inodes_used = data.inodes_used
              brick.device = data.device
              brick.block_size = data.block_size
              brick.mnt_options = data.mnt_options
              brick.fs_name = data.fs_name
            end

            brick
          end

          subvol
        end

        volume
      end
    end

    # :nodoc:
    def self.update_subvol_health(subvol)
      subvol.up_bricks = 0
      subvol.bricks.each do |brick|
        subvol.up_bricks += 1 if brick.state == HEALTH_UP
      end

      subvol.health = HEALTH_UP
      if subvol.bricks.size != subvol.up_bricks
        subvol.health = HEALTH_DOWN
        if subvol.type == TYPE_REPLICATE && subvol.up_bricks >= (subvol.replica_count/2).ceil
          subvol.health = HEALTH_PARTIAL
        end
        # If down bricks are less than or equal to redudancy count
        # then Volume is UP but some bricks are down
        if subvol.type == TYPE_DISPERSE && (subvol.bricks.size - subvol.up_bricks) <= subvol.disperse_redundancy_count
          subvol.health = HEALTH_PARTIAL
        end
      end

      subvol
    end

    # :nodoc:
    def self.update_volume_health(volumes)
      # Update Volume health based on subvolume health
      volumes.map do |volume|
        if volume.state == STATE_STARTED
          volume.health = HEALTH_UP
          volume.up_subvols = 0

          volume.subvols = volume.subvols.map do |subvol|
            # Update Subvolume health based on bricks health
            subvol = update_subvol_health(subvol)

            # One subvol down means the Volume is degraded
            if subvol.health == HEALTH_DOWN
              volume.health = HEALTH_DEGRADED
            end

            # If Volume is not yet degraded, then it
            # may be same as subvolume health
            if subvol.health == HEALTH_PARTIAL && volume.health != HEALTH_DEGRADED
              volume.health = subvol.health
            end

            if subvol.health != HEALTH_DOWN
              volume.up_subvols += 1
            end

            subvol
          end

          if volume.up_subvols == 0
            volume.health = HEALTH_DOWN
          end
        end

        volume
      end
    end

    # :nodoc:
    # TODO: Fix and remove this warning
    # ameba:disable Metrics/CyclomaticComplexity
    def self.update_volume_utilization(volumes)
      volumes.map do |volume|
        volume.subvols = volume.subvols.map do |subvol|
          subvol.size_used = 0
          subvol.size_total = 0
          subvol.inodes_used = 0
          subvol.inodes_total = 0

          # Subvolume utilization
          subvol.bricks.each do |brick|
            next if brick.type == "Arbiter"

            subvol.size_used = brick.size_used if brick.size_used >= subvol.size_used

            if subvol.size_total == 0 ||
               (brick.size_total <= subvol.size_total &&
               brick.size_total > 0)
              subvol.size_total = brick.size_total
            end

            subvol.inodes_used = brick.inodes_used if brick.inodes_used >= subvol.inodes_used

            if subvol.inodes_total == 0 ||
               (brick.inodes_total <= subvol.inodes_total &&
               brick.inodes_total > 0)
              subvol.inodes_total = brick.inodes_total
            end
          end

          # Subvol Size = Sum of size of Data bricks
          if subvol.type == TYPE_DISPERSE
            subvol.size_used = subvol.size_used * (
              subvol.disperse_count - subvol.disperse_redundancy_count
            )

            subvol.size_total = subvol.size_total * (
              subvol.disperse_count - subvol.disperse_redundancy_count
            )

            subvol.inodes_used = subvol.inodes_used * (
              subvol.disperse_count - subvol.disperse_redundancy_count
            )

            subvol.inodes_total = subvol.inodes_total * (
              subvol.disperse_count - subvol.disperse_redundancy_count
            )
          end

          subvol.size_free = subvol.size_total - subvol.size_used
          subvol.inodes_free = subvol.inodes_total - subvol.inodes_used

          # Aggregated volume utilization
          volume.size_total += subvol.size_total
          volume.size_used += subvol.size_used
          volume.size_free = volume.size_total - volume.size_used
          volume.inodes_total += subvol.inodes_total
          volume.inodes_used += subvol.inodes_used
          volume.inodes_free = volume.inodes_total - volume.inodes_used

          subvol
        end

        volume
      end
    end

    # :nodoc:
    def _status
      volumes = Volume.update_brick_status([info], Volume.brick_status(@cli, @name))
      volumes = Volume.update_volume_utilization(volumes)
      Volume.update_volume_health(volumes)[0]
    end

    # :nodoc:
    def self.all_status(cli)
      volumes = Volume.update_brick_status(Volume.list(cli), Volume.brick_status(cli))
      volumes = Volume.update_volume_utilization(volumes)
      Volume.update_volume_health(volumes)
    end

    # Start a Gluster Volume
    #
    # Example:
    # ```
    # cli.volume("gvol1").start
    #
    # # To start with *force* option
    # cli.volume("gvol1").start(force: true)
    # ```
    def start(force = false)
      cmd = ["volume", "start", @name]
      cmd << "force" if force

      @cli.execute_gluster_cmd(cmd)
    end

    # Stop a Gluster Volume
    #
    # Example:
    # ```
    # cli.volume("gvol1").stop
    #
    # # To stop with *force* option
    # cli.volume("gvol1").stop(force: true)
    # ```
    def stop(force = false)
      cmd = ["volume", "stop", @name]
      cmd << "force" if force

      @cli.execute_gluster_cmd(cmd)
    end

    # Set Multiple Volume Options
    #
    # Example:
    # ```
    # cli.volume("gvol1").option_set({"changelog.changelog" => "on"})
    # ```
    def option_set(key_values : Hash(String, String))
      cmd = ["volume", "set", @name]
      key_values.each do |key, value|
        cmd << key
        cmd << value
      end

      @cli.execute_gluster_cmd(cmd)
    end

    # Set a Volume Option
    #
    # Example:
    # ```
    # cli.volume("gvol1").option_set("changelog.changelog", "on")
    # ```
    def option_set(key : String, value : String)
      cmd = ["volume", "set", @name]
      cmd << key
      cmd << value

      @cli.execute_gluster_cmd(cmd)
    end

    # Reset Multiple Volume Options
    #
    # Example:
    # ```
    # cli.volume("gvol1").option_reset(["changelog.changelog"])
    # ```
    def option_reset(keys : Array(String))
      cmd = ["volume", "reset", @name]
      cmd.concat(keys)

      @cli.execute_gluster_cmd(cmd)
    end

    # Reset a Volume Option
    #
    # Example:
    # ```
    # cli.volume("gvol1").option_reset("changelog.changelog")
    # ```
    def option_reset(key : String)
      cmd = ["volume", "reset", @name, key]

      @cli.execute_gluster_cmd(cmd)
    end

    # :nodoc:
    def self.create(cli : CLI, name : String, bricks : Array(String), opts : VolumeCreateOptions)
      # TODO: Handle all other flags
      cmd = ["volume", "create", name]
      cmd.concat(["replica", "#{opts.replica_count}"]) if opts.replica_count > 1
      cmd.concat(["disperse", "#{opts.disperse_count}"]) if opts.disperse_count > 0
      cmd.concat(["redundancy", "#{opts.disperse_redundancy_count}"]) if opts.disperse_redundancy_count > 1

      cmd.concat(bricks)
      cmd << "force" if opts.force

      cli.execute_gluster_cmd(cmd)
    end

    # Delete a Gluster Volume
    #
    # Example:
    # ```
    # cli.volume("gvol1").delete
    # ```
    def delete
      cmd = ["volume", "delete", @name]

      @cli.execute_gluster_cmd(cmd)
    end
  end
end
