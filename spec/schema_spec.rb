require 'spec_helper.rb'

describe 'RFlow::Message::Data::Raw Avro Schema' do
  before(:each) do
    @schema_string = RFlow::Configuration.available_data_types['RFlow::Message::Data::Raw']['avro']
  end

  it "should encode and decode an object" do
    raw = {
      'raw' => Array.new(256) { rand(256) }.pack('c*')
    }

    expect {encode_avro(@schema_string, raw)}.to_not raise_error
    avro_encoded_raw = encode_avro(@schema_string, raw)

    expect {decode_avro(@schema_string, avro_encoded_raw)}.to_not raise_error
    decoded_raw = decode_avro(@schema_string, avro_encoded_raw)

    decoded_raw.should == raw

    p decoded_raw['raw'].encoding
    p raw['raw'].encoding

    decoded_raw['raw'].should == raw['raw']

  end

end
