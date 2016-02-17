require 'spec_helper'

class RFlow
  describe ForwardToInputPort do
    before(:each) do
      ActiveRecord::Base.establish_connection adapter: 'sqlite3', database: ':memory:'
      Configuration.migrate_database
    end

    let(:accepted_messages) { [] }
    let(:dropped_messages) { [] }

    let(:generator) do
      RFlow::Components::GenerateIntegerSequence.new.tap do |c|
        c.configure!({})
      end
    end

    let(:accept_evens) do
      RFlow::Components::RubyProcFilter.new.tap do |c|
        c.configure! 'filter_proc_string' => 'message.data.data_object % 2 == 0'
      end
    end

    it 'should forward generated integers to be filtered by the proc filter' do
      generator.out.direct_connect accept_evens.in

      accept_evens.filtered.collect_messages(nil, accepted_messages) do
        accept_evens.dropped.collect_messages(nil, dropped_messages) do
          5.times { generator.generate }
        end
      end

      expect(accepted_messages).to have(3).messages
      expect(accepted_messages.map(&:data).map(&:data_object)).to eq([0, 2, 4])
      expect(dropped_messages).to have(2).messages
      expect(dropped_messages.map(&:data).map(&:data_object)).to eq([1, 3])
    end

    it 'should forward integers from the union of subports' do
      generator.even_odd_out.direct_connect accept_evens.in

      accept_evens.filtered.collect_messages(nil, accepted_messages) do
        accept_evens.dropped.collect_messages(nil, dropped_messages) do
          5.times { generator.generate }
        end
      end

      expect(accepted_messages).to have(3).messages
      expect(accepted_messages.map(&:data).map(&:data_object)).to eq([0, 2, 4])
      expect(dropped_messages).to have(2).messages
      expect(dropped_messages.map(&:data).map(&:data_object)).to eq([1, 3])
    end

    it 'should forward integers from a subport' do
      generator.even_odd_out['even'].direct_connect accept_evens.in

      accept_evens.filtered.collect_messages(nil, accepted_messages) do
        accept_evens.dropped.collect_messages(nil, dropped_messages) do
          5.times { generator.generate }
        end
      end

      expect(accepted_messages).to have(3).messages
      expect(accepted_messages.map(&:data).map(&:data_object)).to eq([0, 2, 4])
      expect(dropped_messages).to have(0).messages
    end
  end
end
