require 'spec_helper.rb'
require 'rflow/configuration'

describe RFlow::Configuration do
  before(:each) do
  end

  describe '.add_available_data_type' do
    context 'if passed a data_serialization that is not avro or xml' do
      it "should throw an exception" do
        expect do
          RFlow::Configuration.add_available_data_type('A', 'boom', 'schema')
        end.to raise_error(ArgumentError)
      end

      it "should not update the available_data_types" do
        num_types = RFlow::Configuration.available_data_types.size
        RFlow::Configuration.add_available_data_type('A', 'boom', 'schema') rescue nil
        RFlow::Configuration.available_data_types.should have(num_types).items
      end
    end
  end

  describe "Data Extensions" do
    describe ".add_available_data_extension" do
      context 'if passed a non-module data extension' do
        it "should throw an exception" do
          expect do
            RFlow::Configuration.add_available_data_extension('data_type', 'not a Module')
          end.to raise_error(ArgumentError)
        end
      end

      context "if passed a valid Module as a data extension" do
        it "should update the available_data_extensions" do
          num_extensions = RFlow::Configuration.available_data_extensions['data_type'].size
          expect do
            RFlow::Configuration.add_available_data_extension('data_type', Module.new)
          end.to_not raise_error
          RFlow::Configuration.available_data_extensions['data_type'].should have(num_extensions+1).items
        end
      end
    end

    it "should perform simple 'prefix'-based inheritance for extensions" do
      RFlow::Configuration.add_available_data_extension('A', A = Module.new)
      RFlow::Configuration.add_available_data_extension('A::B', B = Module.new)
      RFlow::Configuration.add_available_data_extension('A::B::C', C = Module.new)
      RFlow::Configuration.add_available_data_extension('A::B::C::D', D = Module.new)

      RFlow::Configuration.available_data_extensions['A'].should have(1).item
      RFlow::Configuration.available_data_extensions['A'].should == [A]

      RFlow::Configuration.available_data_extensions['A::B'].should have(2).item
      RFlow::Configuration.available_data_extensions['A::B'].should == [A, B]

      RFlow::Configuration.available_data_extensions['A::B::C'].should have(3).item
      RFlow::Configuration.available_data_extensions['A::B::C'].should == [A, B, C]

      RFlow::Configuration.available_data_extensions['A::B::C::D'].should have(4).item
      RFlow::Configuration.available_data_extensions['A::B::C::D'].should == [A, B, C, D]

      RFlow::Configuration.available_data_extensions['A::B::C::D::E'].should have(4).item
      RFlow::Configuration.available_data_extensions['A::B::C::D::E'].should == [A, B, C, D]
    end
  end
end
