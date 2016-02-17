require 'spec_helper'

class RFlow
  describe ForwardToOutputPort do
    before(:each) do
      ActiveRecord::Base.establish_connection adapter: 'sqlite3', database: ':memory:'
      Configuration.migrate_database
    end

    let(:messages) { [] }

    let(:generator) do
      RFlow::Components::GenerateIntegerSequence.new.tap do |c|
        c.configure!({})
      end
    end

    let(:accept_evens) do
      RFlow::Components::RubyProcFilter.new.tap do |c|
        c.configure! 'filter_proc_string' => 'message % 2 == 0'
      end
    end

    it 'should place the messages on the output port, regardless of the filter' do
      generator.out.direct_connect accept_evens.filtered

      accept_evens.filtered.collect_messages(nil, messages) do
        5.times { generator.generate }
      end
      expect(messages.map(&:data).map(&:data_object)).to eq([0, 1, 2, 3, 4])
    end
  end
end
