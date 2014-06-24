require 'spec_helper'

class RFlow
  class Component
    describe Port do
      it "should not be connected" do
        expect(described_class.new(nil)).not_to be_connected
      end
    end

    describe HashPort do
      it "should not be connected" do
        expect(described_class.new(nil)).not_to be_connected
      end
    end

    describe InputPort do
      context "#connect!" do
        it "should be connected" do
          connection = double('connection')
          allow(connection).to receive(:name)
          allow(connection).to receive(:uuid)
          allow(connection).to receive(:input_port_key)
          expect(connection).to receive(:connect_input!)

          described_class.new(nil).tap do |port|
            port.add_connection(nil, connection)
            expect(port).not_to be_connected
            port.connect!
            expect(port).to be_connected
          end
        end
      end

      context "#(add|remove)_connection" do
        it "should remove the connection" do
          connection = double('connection')
          allow(connection).to receive(:name)
          allow(connection).to receive(:uuid)
          allow(connection).to receive(:input_port_key)

          described_class.new(nil).tap do |port|
            port.add_connection(nil, connection)
            expect(port[nil]).to include connection
            port.remove_connection(nil, connection)
            expect(port[nil]).not_to include connection
          end
        end
      end
    end

    describe OutputPort do
      context "#connect!" do
        it "should be connected" do
          connection = double('connection')
          allow(connection).to receive(:name)
          allow(connection).to receive(:uuid)
          allow(connection).to receive(:input_port_key)
          expect(connection).to receive(:connect_output!)

          described_class.new(nil).tap do |port|
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
