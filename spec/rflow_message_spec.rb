require 'spec_helper.rb'
require 'digest/md5'
require 'rflow/message'

describe RFlow::Message do
  context "if created with an unknown data type" do
    it "should throw an exception" do
      expect {RFlow::Message.new('non_existant_data_type')}.to raise_error(ArgumentError)
    end
  end

  context "if created with a known data type" do
    before(:all) do
      @avro_string_schema_string = '{"type": "string"}'
      RFlow::Configuration.add_available_data_type(:string_type, 'avro', @avro_string_schema_string)
    end

    it "should instantiate correctly" do
      expect {RFlow::Message.new('string_type')}.to_not raise_error
    end

    context "if created with empty provenance" do
      context "if created with an unknown data serialization" do
        it "should throw an exception" do
          expect {RFlow::Message.new('string_type', [], 'unknown')}.to raise_error(ArgumentError)
          expect {RFlow::Message.new('string_type', [], :unknown)}.to raise_error(ArgumentError)
        end
      end

      context "if created with a known data serialization" do
        it "should instantiate correctly" do
          expect {RFlow::Message.new('string_type', [], 'avro')}.to_not raise_error
          expect {RFlow::Message.new('string_type', [], 'avro')}.to_not raise_error
        end

        context "if created with a mismatched schema"
        context "if created with a matched schema"

        context "if created with a nil schema" do
          context "if created with a serialized data object" do
            before(:all) do
              @string = 'this is a string to be serialized'
              @avro_serialized_string = encode_avro(@avro_string_schema_string, @string)
            end

            it "should instantiate correctly" do
              expect {RFlow::Message.new('string_type', [], 'avro', nil, @avro_serialized_string)}.to_not raise_error
              message = RFlow::Message.new('string_type', [], 'avro', nil, @avro_serialized_string)
            end
          end
        end
      end
    end

    context "if created with invalid provenance" do
      before(:all) do
        @invalid_processing_event_hash = {'started_at' => 'bad time string'}
        @invalid_provenance = [@invalid_processing_event_hash]
      end

      it "should throw an exception" do
        expect {RFlow::Message.new('string_type', @invalid_provenance)}.to raise_error(ArgumentError)
      end
    end

    context "if created with valid provenance" do
      before(:all) do
        @valid_xmlschema_time = '2001-01-01T01:01:01.000001Z'
        @valid_processing_event_hash = {'component_instance_uuid' => 'uuid', 'started_at' => @valid_xmlschema_time}
        @valid_processing_event = RFlow::Message::ProcessingEvent.new('uuid', @valid_xmlschema_time, @valid_xmlschema_time, 'context')
        @valid_provenance = [
          RFlow::Message::ProcessingEvent.new('uuid'),
          @valid_processing_event_hash,
          @valid_processing_event]
        @valid_provenance_hashes = [
          {"component_instance_uuid" => "uuid", "started_at" => nil, "completed_at" => nil, "context" => nil},
          {"component_instance_uuid" => "uuid", "started_at" => @valid_xmlschema_time, "completed_at" => nil, "context" => nil},
          {"component_instance_uuid" => "uuid", "started_at" => @valid_xmlschema_time, "completed_at" => @valid_xmlschema_time, "context" => "context"}]
      end

      it "should instantiate correctly" do
        expect {RFlow::Message.new('string_type', @valid_provenance)}.to_not raise_error
      end

      it "should correctly set the provenance processing events" do
        message = RFlow::Message.new('string_type', @valid_provenance)
        message.provenance[1].component_instance_uuid.should == 'uuid'
        message.provenance[1].started_at.should == Time.xmlschema(@valid_xmlschema_time)
        message.provenance[1].completed_at.should == nil
        message.provenance[1].context.should == nil
      end

      it "should to_hash its provenance correctly" do
        message = RFlow::Message.new('string_type', @valid_provenance)
        message.provenance.map(&:to_hash).should == @valid_provenance_hashes
      end
    end

    context "if correctly created" do
      it "should serialize and deserialized correctly to/from avro" do
        message = RFlow::Message.new('string_type')
        message.provenance << RFlow::Message::ProcessingEvent.new('UUID')
        message.data.data_object = 'teh awesome'

        processed_message = RFlow::Message.from_avro(message.to_avro)
        message.data.to_avro.should == processed_message.data.to_avro
        message.data.data_object.should == processed_message.data.data_object
      end
    end

    context "if data extensions exist" do
      it "should extend the data element with the extension" do
        module ExtensionModule; def ext_method; end; end

        message = RFlow::Message.new('string_type')
        message.data.methods.should_not include(:ext_method)

        RFlow::Configuration.add_available_data_extension('string_type', ExtensionModule)
        message = RFlow::Message.new('string_type')
        message.data.methods.should include(:ext_method)
      end
    end
  end

  it "should correctly handle large raw types" do
    message = RFlow::Message.new('RFlow::Message::Data::Raw')
    message.data.raw = Array.new(101) { rand(256) }.pack('c*')

    message_avro = message.to_avro.force_encoding('BINARY')

    processed_message = RFlow::Message.from_avro(message_avro)
    processed_message_avro = processed_message.to_avro.force_encoding('BINARY')

    @raw_schema = RFlow::Configuration.available_data_types['RFlow::Message::Data::Raw']['avro']

    encode_avro(@raw_schema, message.data.data_object).should == message.data.to_avro
    decode_avro(@raw_schema, message.data.to_avro).should == message.data.data_object

    message_data_avro = message.data.to_avro.force_encoding('BINARY')
    processed_message_data_avro = processed_message.data.to_avro.force_encoding('BINARY')

    Digest::MD5.hexdigest(message_avro).should == Digest::MD5.hexdigest(processed_message_avro)

    message_data_avro.should == processed_message_data_avro
    Digest::MD5.hexdigest(message_data_avro).should == Digest::MD5.hexdigest(processed_message_data_avro)
    Digest::MD5.hexdigest(message.data.raw).should == Digest::MD5.hexdigest(processed_message.data.raw)
  end
end
