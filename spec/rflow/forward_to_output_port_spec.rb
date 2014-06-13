require 'spec_helper'

class RFlow
  describe ForwardToOutputPort do
    before(:each) do
      ActiveRecord::Base.establish_connection adapter: "sqlite3", database: ":memory:"
      Configuration.migrate_database
    end

    let(:message_connection) { RFlow::MessageCollectingConnection.new }

    let(:generator) do
      RFlow::Components::GenerateIntegerSequence.new.tap do |c|
        c.configure!({})
        c.configure_output_port! RFlow::Configuration::OutputPort.new(name: 'out')
        c.out.add_connection nil, ForwardToOutputPort.new(ruby_proc_filter, 'filtered')
      end
    end

    let(:ruby_proc_filter) do
      RFlow::Components::RubyProcFilter.new.tap do |c|
        c.configure! 'filter_proc_string' => 'message % 2 == 0'
        c.configure_output_port! RFlow::Configuration::OutputPort.new(name: 'filtered')
        c.filtered.add_connection nil, message_connection
      end
    end

    def messages; message_connection.messages; end

    it 'should place the messages on the output port, regardless of the filter' do
      5.times { generator.generate }
      expect(messages.map(&:data).map(&:data_object)).to eq([0, 1, 2, 3, 4])
    end
  end
end
