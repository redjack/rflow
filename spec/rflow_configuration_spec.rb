require 'spec_helper.rb'

require 'rflow/configuration'

RFlow.logger = Logger.new(STDOUT)

describe RFlow::Configuration do
  describe '#crap' do
    it "does stuff" do
      true
    end
  end

  describe '.add_available_data_type' do

    context 'if passed a data_serialization that is not avro or xml' do
      it "should throw an exception" do
        expect do
          RFlow::Configuration.add_available_data_type('A', :boom, 'schema')
        end.to raise_error(ArgumentError)
      end
      it "should not update the available_data_types" do
        RFlow::Configuration.available_data_types.should have(0).items
        RFlow::Configuration.add_available_data_type('A', :boom, 'schema') rescue nil
        RFlow::Configuration.available_data_types.should have(0).items
      end
    end

  end

  describe ".add_available_data_extension" do
    context 'if passed a non-module data extension' do
      it "should throw an exception" do
        expect do
          RFlow::Configuration.add_available_data_extension('data_type', 'not a Module')
        end.to raise_error(ArgumentError)
      end
    end

    context "if passed a valid Module as a data extension" do
      it "should not throw an exception" do
        expect do
          RFlow::Configuration.add_available_data_extension('data_type', Module.new)
        end.to_not raise_error
      end
      it "should update the available_data_extensions" do
        p RFlow::Configuration.available_data_extensions
        RFlow::Configuration.available_data_extensions.should have(0).items
        RFlow::Configuration.add_available_data_extension('data_type', Module.new)
        RFlow::Configuration.available_data_extensions.should have(1).item
        RFlow::Configuration.available_data_extensions['data_type'].should have(1).item
      end
    end
  end

end
