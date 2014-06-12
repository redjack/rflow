require 'spec_helper'
require 'rflow/components/raw'

class RFlow
  class Message
    class Data
      describe 'Raw Avro Schema' do
        let(:schema) { Configuration.available_data_types['RFlow::Message::Data::Raw']['avro'] }

        it "should load the schema" do
          expect(schema).not_to be_nil
        end

        it "should encode and decode an object" do
          raw = {'raw' => Array.new(256) { rand(256) }.pack('c*')}

          expect { encode_avro(schema, raw) }.to_not raise_error
          encoded = encode_avro(schema, raw)

          expect { decode_avro(schema, encoded) }.to_not raise_error
          decoded = decode_avro(schema, encoded)

          expect(decoded).to eq(raw)
          expect(decoded['raw']).to eq(raw['raw'])
        end
      end
    end
  end
end
