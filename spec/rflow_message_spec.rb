require 'spec_helper.rb'

require 'rflow/message'

describe RFlow::Message do

  context "if created with an unknown data type" do
    it "should throw an exception" do
      expect {RFlow::Message.new('non_existant_data_type')}.to raise_error(ArgumentError)
    end
  end


  
  context "if created with a known data type" do
    before(:all) do
      RFlow::Configuration.add_available_data_type('existing_type', :avro, 'schema')
      RFlow::Configuration.add_available_data_type('existing_type', :xml, 'schema')
    end

    it "should instantiate correctly" do
      expect {RFlow::Message.new('existing_type')}.to_not raise_error
    end

    context "if created with an unknown data serialization" do
      it "should throw an exception" do
        expect {RFlow::Message.new('existing_type', 'unknown')}.to raise_error(ArgumentError)
        expect {RFlow::Message.new('existing_type', :unknown)}.to raise_error(ArgumentError)
      end
    end

    context "if created with a known data serialization" do
      it "should instantiate correctly" do
        expect {RFlow::Message.new('existing_type', :avro)}.to_not raise_error
        expect {RFlow::Message.new('existing_type', 'avro')}.to_not raise_error
        expect {RFlow::Message.new('existing_type', :xml)}.to_not raise_error
        expect {RFlow::Message.new('existing_type', 'xml')}.to_not raise_error
      end
    end

    
    context "if data extensions do not exist" do
    end

    context "if data extensions exist" do
    end
  end
  
end
