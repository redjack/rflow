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

class RFlow::Components::GenerateIntegerSequence < RFlow::Component
  output_port :out
end

class RFlow::Components::Replicate < RFlow::Component
  input_port :in
  output_port [:out]
  output_port :errored
  
  def process_message
    out.each do |out_n|
      begin
        out_n.send message
      rescue Exception => e
        error.send message
      end
    end
  end
end

class RFlow::Components::ProcFilter < RFlow::Component
  input_port :in
  output_port :filtered
  output_port :dropped
  output_port :errored

  def configure(config)
    @filter_proc = config.filter
  end

  def process_message(input_port, message)
    begin
      if @filter_proc.call(message.data)
        filtered.send message
      else
        dropped.send message
      end
    rescue Exception => e
      error.send message
    end
  end
end

class RFlow::Components::FileOutput < RFlow::Component
end

class SimpleComponent < RFlow::Component
  puts "-----------------SimpleComponent"
end

class Complex
  class ComplexComponent < RFlow::Component
    puts "-----------------Complex::ComplexComponent"
  end
end

RFlow::Configuration::RubyDSL.configure do |config|
  # Configure the settings, which include paths for various files, log
  # levels, and component specific stuffs
  config.setting('rflow.log_level', 'DEBUG')
  config.setting('rflow.application_directory_path', '.')

  # Add schemas to the list of available.  Not convinced this is necessary
#  config.schema('schemaname', 'schematype', 'schemadata')

  # Instantiate components
  config.component 'generate_ints', RFlow::Components::GenerateIntegerSequence, :start => 0, :finish => 10, :step => 2
  config.component 'filter', RFlow::Components::ProcFilter, :filter => 'data.integer < 10'
  config.component 'replicate', RFlow::Components::Replicate
  config.component 'simple', SimpleComponent
  config.component 'complex', Complex::ComplexComponent
  config.component 'output', RFlow::Components::FileOutput, :file_path => '/crap/crap/crap'
  
  # Hook components together
  config.connect 'generate_ints#out' => 'filter#in'
  config.connect 'filter#out' => 'replicate#in'
  config.connect 'replicate#out[0]' => 'simple#in'
  config.connect 'replicate#out[1]' => 'complex#in'
  config.connect 'simple#out' => 'output#in'
  config.connect 'complex#out' => 'output#in'
  
  # Rather do the following, but that is for a future version
  
end

  # TODO: Think about whether this should be in config or in separate,
  # runtime config
  #config.component
  #config.connection

