require 'spec_helper'

class RFlow
  module Components
    describe Clock do
      before(:each) do
        ActiveRecord::Base.establish_connection adapter: "sqlite3", database: ":memory:"
        Configuration.migrate_database
      end
      let(:config) do
        RFlow::Configuration::Component.new.tap do |c|
          c.output_ports << RFlow::Configuration::OutputPort.new(name: 'tick_port')
        end
      end
      let(:message_connection) { RFlow::MessageCollectingConnection.new }

      def clock(args = {})
        Clock.new(config).tap do |c|
          c.configure! args
          c.tick_port.connect!
          c.tick_port.add_connection nil, message_connection
        end
      end

      def messages; message_connection.messages; end

      it 'defaults configuration nicely' do
        clock.tap do |c|
          c.clock_name.should == 'Clock'
          c.tick_interval.should == 1
        end
      end

      it 'supports name overrides' do
        clock('name' => 'testname').tap do |c|
          c.clock_name.should == 'testname'
        end
      end

      it 'supports interval overrides for floats' do
        clock('tick_interval' => 1.5).tap do |c|
          c.tick_interval.should == 1.5
        end
      end

      it 'supports interval overrides for strings' do
        clock('tick_interval' => '1.5').tap do |c|
          c.tick_interval.should == 1.5
        end
      end

      it 'should register a timer' do
        EventMachine::PeriodicTimer.should_receive(:new).with(1)
        clock.run!
      end

      it 'should generate a tick message when asked' do
        clock.tap do |c|
          now = Integer(Time.now.to_f * 1000)
          messages.should be_empty
          c.tick
          messages.should have(1).message
          messages.first.tap do |m|
            m.data_type_name.should == 'RFlow::Message::Clock::Tick'
            m.data.name.should == 'Clock'
            m.data.timestamp.should >= now
          end
        end
      end
    end
  end
end
