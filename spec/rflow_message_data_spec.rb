require 'spec_helper.rb'

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
      expect {RFlow::Message::Data.new()}.to raise_error(ArgumentError)
    end
  end

  context "if created with an invalid schema for the serialization" do
    it "should throw and exception" do 
      expect {RFlow::Message::Data.new(@invalid_avro_schema_string)}.to raise_error(ArgumentError)
      expect {RFlow::Message::Data.new(@invalid_avro_schema_string, :avro)}.to raise_error(ArgumentError)
      expect {RFlow::Message::Data.new(@invalid_avro_schema_string, 'avro')}.to raise_error(ArgumentError)
    end
  end
  
  context "if created with a valid avro schema and serialization" do
  end

  context "if created with a valid avro schema" do 
    it "should instantiate correctly" do 
      expect {RFlow::Message::Data.new(@valid_avro_string_schema_string, :avro)}.to_not raise_error
      expect {RFlow::Message::Data.new(@valid_avro_string_schema_string, 'avro')}.to_not raise_error
    end
    
    context "if created with a non-avro data serialization" do
      it "should throw an exception" do
        expect {RFlow::Message::Data.new(@valid_avro_string_schema_string, 'unknown')}.to raise_error(ArgumentError)
        expect {RFlow::Message::Data.new(@valid_avro_string_schema_string, :unknown)}.to raise_error(ArgumentError)
        expect {RFlow::Message::Data.new(@valid_avro_string_schema_string, 'xml')}.to raise_error(ArgumentError)
        expect {RFlow::Message::Data.new(@valid_avro_string_schema_string, :xml)}.to raise_error(ArgumentError)
      end
    end
    
    context "if created with an avro serialization" do
      it "should instantiate correctly" do
        expect {RFlow::Message::Data.new(@valid_avro_string_schema_string, :avro)}.to_not raise_error
        expect {RFlow::Message::Data.new(@valid_avro_string_schema_string, 'avro')}.to_not raise_error
      end

      context "if created with a serialized data object" do
        it "should instantiate correctly" do
          expect {RFlow::Message::Data.new(@valid_avro_string_schema_string, :avro, @avro_serialized_string)}.to_not raise_error
          message = RFlow::Message::Data.new(@valid_avro_string_schema_string, :avro, @avro_serialized_string)
          p message
        end
      end
    end
  end
end
