require 'spec_helper.rb'

describe RFlow::Component::Port do
  it "should not be connected" do
    described_class.new.connected?.should be_false
  end
end

describe RFlow::Component::HashPort do
  it "should not be connected" do
    port = described_class.new('port', '1')
    port.connected?.should be_false
  end
end

describe RFlow::Component::InputPort do
  context ".connect!" do
    it "should be connected" do
      connection_double = double('connection')
      connection_double.should_receive(:connect_input!)

      port = described_class.new('port', '1')
      port.add_connection(nil, connection_double)

      port.connected?.should be_false
      port.connect!
      port.connected?.should be_true
    end
  end
end

describe RFlow::Component::OutputPort do
  context ".connect!" do
    it "should not be connected" do
      connection_double = double('connection')
      connection_double.should_receive(:connect_output!)

      port = described_class.new('port', '1')
      port.add_connection(nil, connection_double)

      port.connected?.should be_false
      port.connect!
      port.connected?.should be_true
    end
  end
end
