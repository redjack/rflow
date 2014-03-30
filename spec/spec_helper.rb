require File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib', 'rflow'))

require 'fileutils'
require 'log4r'

RSpec.configure do |config|
  config.before(:all) do
    RFlow.logger = Log4r::Logger.new 'test'
    RFlow.logger.add Log4r::StdoutOutputter.new('test_stdout', :formatter => RFlow::Logger::LOG_PATTERN_FORMATTER)
    @base_temp_directory_path = File.join(File.dirname(__FILE__), 'tmp')
  end

  config.before(:each) do
    @entropy = Time.now.to_f.to_s
    @temp_directory_path = File.expand_path(File.join(@base_temp_directory_path, @entropy))
    FileUtils.mkdir_p @temp_directory_path
  end

  config.after(:each) do
    FileUtils.rm_rf @base_temp_directory_path
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
