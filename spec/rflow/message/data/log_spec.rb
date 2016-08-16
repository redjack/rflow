require 'spec_helper'
require 'rflow/components/log'

class RFlow
  class Message
    class Data
      describe 'Log Avro Schema' do
        let(:schema) { Configuration.available_data_types['RFlow::Message::Data::Log']['avro'] }

        it 'should load the schema' do
          expect(schema).not_to be_nil
        end

        it 'should support assignment of properties' do
          message = RFlow::Message.new('RFlow::Message::Data::Log')
          timestamp = Time.now.to_i
          message.data.timestamp = timestamp
          message.data.level = 'INFO'
          message.data.text = 'message'

          result = decode_avro(schema, encode_avro(schema, message.data.to_hash))
          expect(result['timestamp']).to eq timestamp
          expect(result['level']).to eq 'INFO'
          expect(result['text']).to eq 'message'
        end

        it 'should encode and decode an object' do
          log = {'timestamp' => Time.now.to_i, 'level' => 'LOGLEVEL', 'text' => 'Log message'}

          expect { encode_avro(schema, log) }.to_not raise_error
          encoded = encode_avro(schema, log)

          expect { decode_avro(schema, encoded) }.to_not raise_error
          decoded = decode_avro(schema, encoded)

          expect(decoded).to eq(log)
          expect(decoded['text']).to eq(log['text'])
        end
      end
    end
  end
end
