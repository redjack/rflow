# Load the necessary components/gems
#require 'rflow/components/mycomponent'
#require '../components/localfile'
# This will/should bring in available components and their schemas
require 'rflow/components'


# Only long integers allowed
long_integer_schema = <<EOS
{
    "type": "record",
    "name": "Integer",
    "namespace": "org.rflow",
    "aliases": [],
    "fields": [
        {"name": "integer", "type": "long"},
    ]
}
EOS

RFlow::Configuration.add_available_data_schema RFlow::Message::Data::AvroSchema.new('Integer', long_integer_schema)

class SimpleDataExtension < RFlow::Message::Data
  puts "-----------------SimpleDataExtension"
end

puts "Before GenerateIntegerSequence"
class RFlow::Components::GenerateIntegerSequence < RFlow::Component
  output_port :out

  def run!
    EM.add_periodic_timer(1) do
      out.send_message 'MESSAGE IS HERE'
    end
  end
  
end

puts "Before Replicate"
class RFlow::Components::Replicate < RFlow::Component
  input_port :in
  output_port :out
  output_port :errored
  
  def process_message(input_port, message)
    out.each do |output_port_key, output_port|
      begin
        output_port.send message
      rescue Exception => e
        error.send message
      end
    end
  end
end

puts "Before RubyProcFilter"
class RFlow::Components::RubyProcFilter < RFlow::Component
  input_port :in
  output_port :filtered
  output_port :dropped
  output_port :errored

  def process_message(input_port, message)
    begin
      if @filter_proc.call(message.data)
        filtered.send message
      else
        dropped.send message
      end
    rescue Exception => e
      errored.send message
    end
  end
end

puts "Before FileOutput"
class RFlow::Components::FileOutput < RFlow::Component
  input_port :in
#  output_port :out
end

puts "Before SimpleComponent"
class SimpleComponent < RFlow::Component
  input_port :in
  output_port :out
end

puts "Before ComplexComponent"
class Complex
  class ComplexComponent < RFlow::Component
    input_port :in
    output_port :out
  end
end


# TODO: figure out what to do with stuff above this line

# Meat of the config file.  Stuff above this should probably be in
# separate gems and/or files that are brought in at runtime.
RFlow::Configuration::RubyDSL.configure do |config|
  # Configure the settings, which include paths for various files, log
  # levels, and component specific stuffs
  config.setting('rflow.log_level', 'DEBUG')
  config.setting('rflow.application_directory_path', '.')

  # Add schemas to the list of available.  Not convinced this is necessary
#  config.schema('schemaname', 'schematype', 'schemadata')

  # Instantiate components
  config.component 'generate_ints', RFlow::Components::GenerateIntegerSequence, :start => 0, :finish => 10, :step => 2
  config.component 'filter', RFlow::Components::RubyProcFilter, :filter => 'data.integer < 10'
  config.component 'replicate', RFlow::Components::Replicate
  config.component 'simple', SimpleComponent
  config.component 'complex', Complex::ComplexComponent
  config.component 'output', RFlow::Components::FileOutput, :file_path => '/crap/crap/crap'
  
  # Hook components together
  # config.connect 'generate_ints#out' => 'filter#in'
  # config.connect 'filter#filtered' => 'replicate#in'
  # config.connect 'replicate#out[0]' => 'simple#in'
  # config.connect 'replicate#out[one]' => 'complex#in'
  # config.connect 'simple#out' => 'output#in'
  # config.connect 'complex#out' => 'output#in'

  config.connect 'generate_ints#out' => 'filter#in'
  
  # Some tests that should fail
  # output should not have an 'out' ports
#  config.connect 'output#out' => 'simple#in'
end


