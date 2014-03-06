require File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib', 'rflow'))

require 'fileutils'
require 'log4r'

RSpec.configure do |config|
  config.before(:all) do
    RFlow.logger = Log4r::Logger.new 'test'
    RFlow.logger.add Log4r::StdoutOutputter.new('test_stdout', :formatter => RFlow::LOG_PATTERN_FORMATTER)
  end

  config.around(:each) do |example|
    @temp_directory_path = File.expand_path(File.join(File.dirname(__FILE__), 'tmp'))
    Dir.mkdir @temp_directory_path

    example.run

    FileUtils.rm_rf @temp_directory_path
  end
end


def decode_avro(schema_string, serialized_object)
  schema = Avro::Schema.parse(schema_string)
  serialized_object.force_encoding 'BINARY'
  sio = StringIO.new(serialized_object)
  Avro::IO::DatumReader.new(schema, schema).read Avro::IO::BinaryDecoder.new(sio)
end

def encode_avro(schema_string, object)
  encoded_string = ''
  encoded_string.force_encoding 'BINARY'
  schema = Avro::Schema.parse(schema_string)
  sio = StringIO.new(encoded_string)
  Avro::IO::DatumWriter.new(schema).write object, Avro::IO::BinaryEncoder.new(sio)
  encoded_string
end
