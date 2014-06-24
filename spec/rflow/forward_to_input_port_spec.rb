require 'spec_helper'

class RFlow
  describe ForwardToInputPort do
    before(:each) do
      ActiveRecord::Base.establish_connection adapter: "sqlite3", database: ":memory:"
      Configuration.migrate_database
    end

    let(:filtered_messages) { [] }
    let(:dropped_messages) { [] }

    let(:generator) do
      RFlow::Components::GenerateIntegerSequence.new.tap do |c|
        c.configure!({})
        c.out.direct_connect ruby_proc_filter.in
      end
    end

    let(:ruby_proc_filter) do
      RFlow::Components::RubyProcFilter.new.tap do |c|
        c.configure! 'filter_proc_string' => 'message.data.data_object % 2 == 0'
      end
    end

    it 'should forward generated integers to be filtered by the proc filter' do
      ruby_proc_filter.filtered.collect_messages(nil, filtered_messages) do
        ruby_proc_filter.dropped.collect_messages(nil, dropped_messages) do
          5.times { generator.generate }
        end
      end

      expect(filtered_messages).to have(3).messages
      expect(filtered_messages.map(&:data).map(&:data_object)).to eq([0, 2, 4])
      expect(dropped_messages).to have(2).messages
      expect(dropped_messages.map(&:data).map(&:data_object)).to eq([1, 3])
    end
  end
end

