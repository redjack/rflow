require 'spec_helper.rb'

require 'rflow/message'

describe RFlow::Message do

  it "should instantiate with known data type" do
    RFlow::Configuration.add_available_data_type('type', :avro, 'schema')
    RFlow::Message.new('type')
  end

  context 'if passed a data type that is not found in the configuration' do
    it "should throw an exception" do
      expect do
        RFlow::Message.new('non_existant_data_type')
      end.to raise_error(ArgumentError)
    end
  end
  
  
end
