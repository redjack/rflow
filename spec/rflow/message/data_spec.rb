require 'spec_helper'
require 'rflow/message'

describe RFlow::Message::Data do
  before(:all) do
    @string = 'this is a string to be serialized'
    @invalid_avro_schema_string = 'invalid schema'
    @valid_avro_string_schema_string = '{"type": "string"}'
    @avro_serialized_string = encode_avro(@valid_avro_string_schema_string, @string)
  end

  context "if created without a schema" do
    it "should throw an exception" do
      expect {RFlow::Message::Data.new(nil)}.to raise_error(ArgumentError, /^Invalid schema/)
    end
  end

  context "if created with an invalid schema for the serialization" do
    ['avro', :avro].each do |it|
      it "should throw an exception for serialization type #{it.inspect}" do
        expect {RFlow::Message::Data.new(@invalid_avro_schema_string, it)}.to raise_error(ArgumentError, /^Invalid schema/)
      end
    end
  end

  context "if created with a valid avro schema" do
    ['avro', :avro].each do |it|
      it "should instantiate correctly for serialization type #{it.inspect}" do
        expect {RFlow::Message::Data.new(@valid_avro_string_schema_string, it)}.to_not raise_error
      end
    end

    context "if created with a non-avro data serialization" do
      ['unknown', :unknown, 'xml', :xml].each do |it|
        it "should throw an exception for serialization type #{it.inspect}" do
          expect {RFlow::Message::Data.new(@valid_avro_string_schema_string, it)}.to raise_error(
            ArgumentError, 'Only Avro serialization_type supported at the moment')
        end
      end
    end

    context "if created with an avro serialization" do
      it "should instantiate correctly" do
        expect {RFlow::Message::Data.new(@valid_avro_string_schema_string, 'avro')}.to_not raise_error
        expect {RFlow::Message::Data.new(@valid_avro_string_schema_string, 'avro')}.to_not raise_error
      end

      context "if created with a serialized data object" do
        it "should instantiate correctly" do
          expect {RFlow::Message::Data.new(@valid_avro_string_schema_string, 'avro', @avro_serialized_string)}.to_not raise_error
        end
      end
    end
  end
end
