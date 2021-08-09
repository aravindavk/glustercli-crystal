# GlusterFS CLI bindings - Crystal

## Super Simple

```crystal
require "glustercli"

cli = GlusterCLI::CLI.new

# List all Peers
puts cli.list_peers

# List all Volumes information
puts cli.list_volumes

# List all Volumes with status
puts cli.list_volumes(status: true)

# Info of a single Volume
puts cli.volume("gvol1").info

# Volume info with status info
puts cli.volume("gvol1").info(status: true)

# JSON output
puts cli.list_peers.to_json
puts cli.list_volumes(status: true).to_json
```

## Installation

Add this to your application's shard.yml:

```yaml
dependencies:
  glustercli:
    github: aravindavk/glustercli-crystal
```
