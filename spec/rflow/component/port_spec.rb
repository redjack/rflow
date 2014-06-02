require 'spec_helper'

class RFlow
  class Component
    describe Port do
      it "should not be connected" do
        described_class.new.should_not be_connected
      end
    end

    describe HashPort do
      it "should not be connected" do
        config = double('Port Config')
        config.stub(:name).and_return('port')
        config.stub(:uuid).and_return('1')

        described_class.new(config).should_not be_connected
      end
    end

    describe InputPort do
      context "#connect!" do
        it "should be connected" do
          connection = double('connection')
          connection.should_receive(:connect_input!)

          config = double('Port Config')
          config.stub(:name).and_return('port')
          config.stub(:uuid).and_return('1')

          described_class.new(config).tap do |port|
            port.add_connection(nil, connection)
            port.should_not be_connected
            port.connect!
            port.should be_connected
          end
        end
      end
    end

    describe OutputPort do
      context "#connect!" do
        it "should be connected" do
          connection = double('connection')
          connection.should_receive(:connect_output!)

          port_config = double('Port Config')
          port_config.stub(:name).and_return('port')
          port_config.stub(:uuid).and_return('1')

          described_class.new(port_config).tap do |port|
            port.add_connection(nil, connection)
            port.should_not be_connected
            port.connect!
            port.should be_connected
          end
        end
      end
    end
  end
end
