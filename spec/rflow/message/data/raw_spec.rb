require 'spec_helper'
require 'rflow/components/raw'

class RFlow
  class Message
    class Data
      describe 'Raw Avro Schema' do
        before(:each) do
          @schema_string = Configuration.available_data_types['RFlow::Message::Data::Raw']['avro']
        end

        it "should load the schema" do
          @schema_string.should_not == nil
        end

        it "should encode and decode an object" do
          raw = {'raw' => Array.new(256) { rand(256) }.pack('c*')}

          expect {encode_avro(@schema_string, raw)}.to_not raise_error
          avro_encoded_raw = encode_avro(@schema_string, raw)

          expect {decode_avro(@schema_string, avro_encoded_raw)}.to_not raise_error
          decoded_raw = decode_avro(@schema_string, avro_encoded_raw)

          decoded_raw.should == raw
          decoded_raw['raw'].should == raw['raw']
        end
      end
    end
  end
end
