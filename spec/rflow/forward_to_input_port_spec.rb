require 'spec_helper'

class RFlow
  describe ForwardToInputPort do
    before(:each) do
      ActiveRecord::Base.establish_connection adapter: "sqlite3", database: ":memory:"
      Configuration.migrate_database
    end

    let(:filtered_message_connection) { RFlow::MessageCollectingConnection.new }
    let(:dropped_message_connection) { RFlow::MessageCollectingConnection.new }

    let(:generator) do
      RFlow::Components::GenerateIntegerSequence.new.tap do |c|
        c.configure!({})
        c.configure_output_port! RFlow::Configuration::OutputPort.new(name: 'out')
        c.out.add_connection nil, ForwardToInputPort.new(ruby_proc_filter, 'in', nil)
      end
    end

    let(:ruby_proc_filter) do
      RFlow::Components::RubyProcFilter.new.tap do |c|
        c.configure! 'filter_proc_string' => 'message.data.data_object % 2 == 0'
        c.configure_input_port! RFlow::Configuration::InputPort.new(name: 'in')
        ['filtered', 'dropped'].each {|p| c.configure_output_port! RFlow::Configuration::OutputPort.new(name: p) }
        c.filtered.add_connection nil, filtered_message_connection
        c.dropped.add_connection nil, dropped_message_connection
      end
    end

    def filtered_messages; filtered_message_connection.messages; end
    def dropped_messages; dropped_message_connection.messages; end

    it 'should forward generated integers to be filtered by the proc filter' do
      5.times { generator.generate }
      expect(filtered_messages).to have(3).messages
      expect(filtered_messages.map(&:data).map(&:data_object)).to eq([0, 2, 4])
      expect(dropped_messages).to have(2).messages
      expect(dropped_messages.map(&:data).map(&:data_object)).to eq([1, 3])
    end
  end
end

