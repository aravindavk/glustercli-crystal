require "../src/glustercli"

cli = GlusterCLI::CLI.new

puts cli.list_peers

# puts cli.list_volumes

puts cli.volume("gvol1").info.to_json

# puts cli.list_volumes(status: true).to_json
puts cli.volume("gvol1").info(status: true).to_json

# Local Metrics
puts cli.local_metrics.to_json
