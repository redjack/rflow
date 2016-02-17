require 'spec_helper'

class RFlow
  class Component
    context 'Input and output ports' do
      let(:connection) { RFlow::Connection.new(RFlow::Configuration::NullConnectionConfiguration.new) }
      let(:message) { RFlow::Message.new('RFlow::Message::Data::Raw') }

      describe Port do
        it 'should not be connected' do
          expect(described_class.new(nil)).not_to be_connected
        end
      end

      describe HashPort do
        it 'should not be connected' do
          expect(described_class.new(nil)).not_to be_connected
        end
      end

      [InputPort, OutputPort].each do |c|
        describe c do
          context '#add_connection' do
            it 'should add the connection' do
              described_class.new(nil).tap do |port|
                port.add_connection(nil, connection)
                expect(port[nil]).to include connection
              end
            end
          end

          context '#remove_connection' do
            it 'should remove the connection' do
              described_class.new(nil).tap do |port|
                port.add_connection(nil, connection)
                port.remove_connection(nil, connection)
                expect(port[nil]).not_to include connection
              end
            end
          end
        end
      end

      describe InputPort do
        context '#connect!' do
          it 'should be connected' do
            expect(connection).to receive(:connect_input!)

            described_class.new(nil).tap do |port|
              port.add_connection(nil, connection)
              expect(port).not_to be_connected
              port.connect!
              expect(port).to be_connected
            end
          end
        end
      end

      describe OutputPort do
        context '#connect!' do
          it 'should be connected' do
            expect(connection).to receive(:connect_output!)

            described_class.new(nil).tap do |port|
              port.add_connection(nil, connection)
              expect(port).not_to be_connected
              port.connect!
              expect(port).to be_connected
            end
          end
        end

        context '#add_connection' do
          it 'should deliver messages to the new connection' do
            described_class.new(nil).tap do |port|
              port.connect!
              port.all_connections # trigger caching

              expect(connection).to receive(:connect_output!)
              expect(connection).to receive(:send_message).with(message)
              port.add_connection(nil, connection)

              port.send_message(message)
            end
          end
        end

        context '#remove_connection' do
          it 'should not deliver messages to the old connection' do
            described_class.new(nil).tap do |port|
              allow(connection).to receive(:connect_output!)
              port.add_connection(nil, connection)
              port.connect!
              port.all_connections # trigger caching

              expect(connection).not_to receive(:send_message)
              port.remove_connection(nil, connection)

              port.send_message(message)
            end
          end
        end
      end
    end
  end
end
