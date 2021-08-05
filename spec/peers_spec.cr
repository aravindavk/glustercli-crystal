require "spec"
require "../src/glustercli"

describe GlusterCLI::CLI do
  describe "list_peers" do
    it "validates the list_peers information" do
      cli = GlusterCLI::CLI.new
      peers = cli.list_peers
      peers.size.should eq 1
      peers[0].should be_a GlusterCLI::NodeInfo
      peers[0].hostname.should eq "sandbox"
      peers[0].connected.should be_true
    end
  end
end
