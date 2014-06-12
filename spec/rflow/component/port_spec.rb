require 'spec_helper'

class RFlow
  class Component
    describe Port do
      it "should not be connected" do
        expect(described_class.new).not_to be_connected
      end
    end

    describe HashPort do
      it "should not be connected" do
        config = double('Port Config')
        allow(config).to receive(:name).and_return('port')
        allow(config).to receive(:uuid).and_return('1')

        expect(described_class.new(config)).not_to be_connected
      end
    end

    describe InputPort do
      context "#connect!" do
        it "should be connected" do
          connection = double('connection')
          expect(connection).to receive(:connect_input!)

          config = double('Port Config')
          allow(config).to receive(:name).and_return('port')
          allow(config).to receive(:uuid).and_return('1')

          described_class.new(config).tap do |port|
            port.add_connection(nil, connection)
            expect(port).not_to be_connected
            port.connect!
            expect(port).to be_connected
          end
        end
      end
    end

    describe OutputPort do
      context "#connect!" do
        it "should be connected" do
          connection = double('connection')
          expect(connection).to receive(:connect_output!)

          port_config = double('Port Config')
          allow(port_config).to receive(:name).and_return('port')
          allow(port_config).to receive(:uuid).and_return('1')

          described_class.new(port_config).tap do |port|
            port.add_connection(nil, connection)
            expect(port).not_to be_connected
            port.connect!
            expect(port).to be_connected
          end
        end
      end
    end
  end
end
