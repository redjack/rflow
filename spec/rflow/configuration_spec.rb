require 'spec_helper'
require 'rflow/configuration'

class RFlow
  describe Configuration do
    describe '.add_available_data_type' do
      context 'if passed a data_serialization that is not avro' do
        it 'should throw an exception' do
          expect { Configuration.add_available_data_type('A', 'boom', 'schema') }.to raise_error(
            ArgumentError, "Data serialization_type must be 'avro' for 'A'")
        end

        it 'should not update the available_data_types' do
          expect {
            Configuration.add_available_data_type('A', 'boom', 'schema') rescue nil
          }.not_to change { Configuration.available_data_types.size }
        end
      end
    end

    describe 'Data Extensions' do
      describe '.add_available_data_extension' do
        context 'if passed a non-module data extension' do
          it 'should throw an exception' do
            expect {
              Configuration.add_available_data_extension('data_type', 'NOTAMODULE')
            }.to raise_error(ArgumentError, 'Invalid data extension NOTAMODULE for data_type.  Only Ruby Modules allowed')
          end
        end

        context 'if passed a valid Module as a data extension' do
          it 'should update the available_data_extensions' do
            expect {
              Configuration.add_available_data_extension('data_type', Module.new)
            }.to change { Configuration.available_data_extensions['data_type'].size }.by(1)
          end
        end
      end

      it "should perform simple 'prefix'-based inheritance for extensions" do
        Configuration.add_available_data_extension('A', A = Module.new)
        Configuration.add_available_data_extension('A::B', B = Module.new)
        Configuration.add_available_data_extension('A::B::C', C = Module.new)
        Configuration.add_available_data_extension('A::B::C::D', D = Module.new)

        expect(Configuration.available_data_extensions['A']).to eq([A])
        expect(Configuration.available_data_extensions['A::B']).to eq([A, B])
        expect(Configuration.available_data_extensions['A::B::C']).to eq([A, B, C])
        expect(Configuration.available_data_extensions['A::B::C::D']).to eq([A, B, C, D])
        expect(Configuration.available_data_extensions['A::B::C::D::E']).to eq([A, B, C, D])
      end
    end
  end
end
