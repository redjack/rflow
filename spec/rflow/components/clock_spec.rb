require 'spec_helper'

class RFlow
  module Components
    describe Clock do
      before(:each) do
        ActiveRecord::Base.establish_connection adapter: "sqlite3", database: ":memory:"
        Configuration.migrate_database
      end

      let(:messages) { [] }

      def clock(args = {})
        Clock.new.tap do |c|
          c.configure! args
        end
      end

      it 'defaults configuration nicely' do
        clock.tap do |c|
          expect(c.clock_name).to eq('Clock')
          expect(c.tick_interval).to eq(1)
        end
      end

      it 'supports name overrides' do
        clock('name' => 'testname').tap do |c|
          expect(c.clock_name).to eq('testname')
        end
      end

      it 'supports interval overrides for floats' do
        clock('tick_interval' => 1.5).tap do |c|
          expect(c.tick_interval).to eq(1.5)
        end
      end

      it 'supports interval overrides for strings' do
        clock('tick_interval' => '1.5').tap do |c|
          expect(c.tick_interval).to eq(1.5)
        end
      end

      it 'should register a timer' do
        expect(EventMachine::PeriodicTimer).to receive(:new).with(1)
        clock.run!
      end

      it 'should generate a tick message when asked' do
        clock.tap do |c|
          c.tick_port.collect_messages(nil, messages) do
            now = Integer(Time.now.to_f * 1000)
            expect(messages).to be_empty
            c.tick
            expect(messages).to have(1).message
            messages.first.tap do |m|
              expect(m.data_type_name).to eq('RFlow::Message::Clock::Tick')
              expect(m.data.name).to eq('Clock')
              expect(m.data.timestamp).to be >= now
            end
          end
        end
      end
    end
  end
end
