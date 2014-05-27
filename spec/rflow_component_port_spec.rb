require 'spec_helper.rb'

describe RFlow::Component::Port do
  it "should not be connected" do
    described_class.new.connected?.should be_false
  end
end

describe RFlow::Component::HashPort do
  it "should not be connected" do
    port_config = double('Port Config')
    port_config.should_receive(:name).and_return('port')
    port_config.should_receive(:uuid).and_return('1')

    port = described_class.new(port_config)
    port.connected?.should be_false
  end
end

describe RFlow::Component::InputPort do
  context "#connect!" do
    it "should be connected" do
      connection_double = double('connection')
      connection_double.should_receive(:connect_input!)

      port_config = double('Port Config')
      port_config.should_receive(:name).and_return('port')
      port_config.should_receive(:uuid).and_return('1')

      port = described_class.new(port_config)
      port.add_connection(nil, connection_double)

      port.connected?.should be_false
      port.connect!
      port.connected?.should be_true
    end
  end
end

describe RFlow::Component::OutputPort do
  context "#connect!" do
    it "should be connected" do
      connection_double = double('connection')
      connection_double.should_receive(:connect_output!)

      port_config = double('Port Config')
      port_config.should_receive(:name).and_return('port')
      port_config.should_receive(:uuid).and_return('1')

      port = described_class.new(port_config)
      port.add_connection(nil, connection_double)

      port.connected?.should be_false
      port.connect!
      port.connected?.should be_true
    end
  end
end
