require "./glustercli"

puts GlusterCLI.list_peers

puts GlusterCLI.list_volumes

puts GlusterCLI.volume("gvol1").info.to_json

puts GlusterCLI.list_volume_status.to_json
puts GlusterCLI.volume("gvol1").status.to_json
