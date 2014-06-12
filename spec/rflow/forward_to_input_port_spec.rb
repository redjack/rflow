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
      config = RFlow::Configuration::Component.new.tap do |c|
        c.output_ports << RFlow::Configuration::OutputPort.new(name: 'out')
      end
      RFlow::Components::GenerateIntegerSequence.new(config).tap do |c|
        c.configure! config.options
        c.out.add_connection nil, ForwardToInputPort.new(ruby_proc_filter, 'in', nil)
      end
    end

    let(:ruby_proc_filter) do
      config = RFlow::Configuration::Component.new.tap do |c|
        c.input_ports << RFlow::Configuration::InputPort.new(name: 'in')
        ['filtered', 'dropped'].each {|p| c.output_ports << RFlow::Configuration::OutputPort.new(name: p) }
        c.options = {'filter_proc_string' => 'message.data.data_object % 2 == 0'}
      end
      RFlow::Components::RubyProcFilter.new(config).tap do |c|
        c.configure! config.options
        c.filtered.add_connection nil, filtered_message_connection
        c.dropped.add_connection nil, dropped_message_connection
      end
    end

    def filtered_messages; filtered_message_connection.messages; end
    def dropped_messages; dropped_message_connection.messages; end

    it 'should forward generated integers to be filtered by the proc filter' do
      5.times { generator.generate }
      filtered_messages.should have(3).messages
      filtered_messages.map(&:data).map(&:data_object).should == [0, 2, 4]
      dropped_messages.should have(2).messages
      dropped_messages.map(&:data).map(&:data_object).should == [1, 3]
    end
  end
end

