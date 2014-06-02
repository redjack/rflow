require 'spec_helper'
require 'digest/md5'
require 'rflow/message'

class RFlow
  describe Message do
    context "if created with an unknown data type" do
      it "should throw an exception" do
        expect { Message.new('non_existent_data_type') }.to raise_error(
          ArgumentError, "Data type 'non_existent_data_type' with serialization_type 'avro' not found")
      end
    end

    context "if created with a known data type" do
      before(:all) do
        @schema = '{"type": "string"}'
        Configuration.add_available_data_type(:string_type, 'avro', @schema)
      end

      it "should instantiate correctly" do
        expect { Message.new('string_type') }.to_not raise_error
      end

      context "if created with empty provenance" do
        context "if created with an unknown data serialization" do
          ['unknown', :unknown].each do |it|
            it "should throw an exception for #{it.inspect}" do
              expect { Message.new('string_type', [], it) }.to raise_error(
                ArgumentError, "Data type 'string_type' with serialization_type 'unknown' not found")
            end
          end
        end

        context "if created with a known data serialization" do
          ['avro', :avro].each do |it|
            it "should instantiate correctly for #{it.inspect}" do
              expect { Message.new('string_type', [], it) }.to_not raise_error
            end
          end

          context "if created with a mismatched schema" do
            it
          end
          context "if created with a matched schema" do
            it
          end

          context "if created with a nil schema" do
            context "if created with a serialized data object" do
              let(:serialized_string) { encode_avro(@schema, 'this is a string to be serialized') }

              it "should instantiate correctly" do
                expect { Message.new('string_type', [], 'avro', nil, serialized_string) }.to_not raise_error
              end
            end
          end
        end
      end

      context "if created with invalid provenance" do
        let(:invalid_processing_event_hash) { {'started_at' => 'bad time string'} }
        let(:invalid_provenance) { [invalid_processing_event_hash] }

        it "should throw an exception" do
          expect { Message.new('string_type', invalid_provenance) }.to raise_error(
            ArgumentError, 'invalid date: "bad time string"')
        end
      end

      context "if created with valid provenance" do
        let(:valid_xmlschema_time) { '2001-01-01T01:01:01.000001Z' }
        let(:valid_processing_event_hash) { {'component_instance_uuid' => 'uuid', 'started_at' => valid_xmlschema_time } }
        let(:valid_processing_event) { Message::ProcessingEvent.new('uuid', valid_xmlschema_time, valid_xmlschema_time, 'context') }
        let(:valid_provenance) do
          [Message::ProcessingEvent.new('uuid'),
           valid_processing_event_hash,
           valid_processing_event]
        end

        it "should instantiate correctly" do
          expect { Message.new('string_type', valid_provenance) }.to_not raise_error
        end

        it "should correctly set the provenance processing events" do
          Message.new('string_type', valid_provenance).provenance[1].tap do |p|
            p.component_instance_uuid.should == 'uuid'
            p.started_at.should == Time.xmlschema(valid_xmlschema_time)
            p.completed_at.should be_nil
            p.context.should be_nil
          end
        end

        it "should to_hash its provenance correctly" do
          Message.new('string_type', valid_provenance).provenance.map(&:to_hash).should == [
            {"component_instance_uuid" => "uuid", "started_at" => nil, "completed_at" => nil, "context" => nil},
            {"component_instance_uuid" => "uuid", "started_at" => valid_xmlschema_time, "completed_at" => nil, "context" => nil},
            {"component_instance_uuid" => "uuid", "started_at" => valid_xmlschema_time, "completed_at" => valid_xmlschema_time, "context" => "context"}]
        end
      end

      context "if correctly created" do
        it "should serialize and deserialize correctly to/from avro" do
          message = Message.new('string_type').tap do |m|
            m.provenance << Message::ProcessingEvent.new('UUID')
            m.data.data_object = 'teh awesome'
          end

          Message.from_avro(message.to_avro).tap do |processed|
            processed.data.to_avro.should == message.data.to_avro
            processed.data.data_object.should == message.data.data_object
          end
        end
      end

      context "if data extensions exist" do
        it "should extend the data element with the extension" do
          module ExtensionModule; def ext_method; end; end

          message = Message.new('string_type')
          message.data.methods.should_not include(:ext_method)

          Configuration.add_available_data_extension('string_type', ExtensionModule)
          message = Message.new('string_type')
          message.data.methods.should include(:ext_method)
        end
      end
    end

    it "should correctly handle large raw types" do
      message = Message.new('RFlow::Message::Data::Raw').tap do |m|
        m.data.raw = Array.new(101) { rand(256) }.pack('c*')
      end

      message_avro = message.to_avro.force_encoding('BINARY')

      processed_message = Message.from_avro(message_avro)
      processed_message_avro = processed_message.to_avro.force_encoding('BINARY')

      @raw_schema = Configuration.available_data_types['RFlow::Message::Data::Raw']['avro']

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
end
