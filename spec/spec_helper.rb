require File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib', 'rflow'))

require 'fileutils'
require 'log4r'
require 'rspec/collection_matchers'
require 'tmpdir'

I18n.enforce_available_locales = true

RSpec.configure do |config|
  config.before(:each) do
    @temp_directory_path = Dir.mktmpdir('rflow')
  end

  config.after(:each) do
    FileUtils.rm_rf @temp_directory_path
  end
end

def decode_avro(schema_string, bytes)
  schema = Avro::Schema.parse(schema_string)
  RFlow::Avro.decode(Avro::IO::DatumReader.new(schema, schema), bytes)
end

def encode_avro(schema_string, message)
  RFlow::Avro.encode(Avro::IO::DatumWriter.new(Avro::Schema.parse(schema_string)), message)
end
