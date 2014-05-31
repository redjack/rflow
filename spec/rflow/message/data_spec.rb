require 'spec_helper'
require 'rflow/message'

class RFlow
  class Message
    describe Data do
      let(:string) { 'this is a string to be serialized' }
      let(:invalid_schema) { 'invalid schema' }
      let(:valid_schema) { '{"type": "string"}' }
      let(:serialized_string) { encode_avro(valid_schema, string) }

      context "if created without a schema" do
        it "should throw an exception" do
          expect { Data.new(nil) }.to raise_error(ArgumentError, /^Invalid schema/)
        end
      end

      context "if created with an invalid schema for the serialization" do
        ['avro', :avro].each do |it|
          it "should throw an exception for serialization type #{it.inspect}" do
            expect { Data.new(invalid_schema, it) }.to raise_error(ArgumentError, /^Invalid schema/)
          end
        end
      end

      context "if created with a valid avro schema" do
        ['avro', :avro].each do |it|
          it "should instantiate correctly for serialization type #{it.inspect}" do
            expect { Data.new(valid_schema, it) }.to_not raise_error
          end
        end

        context "if created with a non-avro data serialization" do
          ['unknown', :unknown, 'xml', :xml].each do |it|
            it "should throw an exception for serialization type #{it.inspect}" do
              expect { Data.new(valid_schema, it) }.to raise_error(
                ArgumentError, 'Only Avro serialization_type supported at the moment')
            end
          end
        end

        context "if created with an avro serialization" do
          ['avro', :avro].each do |it|
            it "should instantiate correctly for serialization type #{it.inspect}" do
              expect { Data.new(valid_schema, it) }.to_not raise_error
            end
          end

          context "if created with a serialized data object" do
            it "should instantiate correctly" do
              expect { Data.new(valid_schema, 'avro', serialized_string )}.to_not raise_error
            end
          end
        end
      end
    end
  end
end
