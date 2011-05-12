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

  attr_accessor :count
  
  def run!
    count = 0
    EM.add_periodic_timer(1) do
      count += 1
      out.send_message "#{self.class} '#{name}' (#{object_id}) sent #{count}"
    end
  end
  
end

puts "Before Replicate"
class RFlow::Components::Replicate < RFlow::Component
  input_port :in
  output_port :out
  output_port :errored
  
  def process_message(input_port, input_port_key, connection, message)
    out.each do |output_port|
      begin
        output_port.send_message message
      rescue Exception => e
        puts "Exception #{e.message}"
        error.send_message message
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


  def configure!(deserialized_configuration)
    @filter_proc = eval(deserialized_configuration[:filter_proc_string])
  end
  
  def process_message(input_port, input_port_key, connection, message)
    puts "Processing message in RubyProcFilter"
    begin
      if @filter_proc.call(message)
        filtered.send_message message
      else
        dropped.send_message message
      end
    rescue Exception => e
      puts "Attempting to send message to errored #{e.message}"
      p errored
      errored.send_message message
    end
  end
end

puts "Before FileOutput"
class RFlow::Components::FileOutput < RFlow::Component
  attr_accessor :output_file_path, :output_file
  input_port :in

  def configure!(deserialized_configuration)
    self.output_file_path = deserialized_configuration[:output_file_path]
    self.output_file = File.new output_file_path, 'w+'
  end

  #def run!; end
  
  def process_message(input_port, input_port_key, connection, message)
    puts "About to output to a file #{output_file_path}"
    output_file.puts message
  end

  
  def cleanup
    output_file.close
  end
  
end

# TODO: Ensure that all the following methods work as they are
# supposed to.  This is the interface that I'm adhering to
class SimpleComponent < RFlow::Component
  input_port :in
  output_port :out

  def configure!(configuration); end
  def run!; end
  def process_message(input_port, input_port_key, connection, message); end
  def shutdown!; end
  def cleanup!; end
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
  config.component 'generate_ints1', RFlow::Components::GenerateIntegerSequence, :start => 0, :finish => 10, :step => 2
  config.component 'generate_ints2', RFlow::Components::GenerateIntegerSequence, :start => 0, :finish => 10, :step => 2
  config.component 'filter', RFlow::Components::RubyProcFilter, :filter_proc_string => 'lambda {|message| true}'
  config.component 'replicate', RFlow::Components::Replicate
#  config.component 'simple', SimpleComponent
#  config.component 'complex', Complex::ComplexComponent
  config.component 'output1', RFlow::Components::FileOutput, :output_file_path => '/tmp/crap1'
  config.component 'output2', RFlow::Components::FileOutput, :output_file_path => '/tmp/crap2'
  
  # Hook components together
  # config.connect 'generate_ints#out' => 'filter#in'
  # config.connect 'filter#filtered' => 'replicate#in'
  # config.connect 'replicate#out[0]' => 'simple#in'
  # config.connect 'replicate#out[one]' => 'complex#in'
  # config.connect 'simple#out' => 'output#in'
  # config.connect 'complex#out' => 'output#in'

  config.connect 'generate_ints1#out' => 'filter#in'
#  config.connect 'generate_ints2#out' => 'filter#in'
  config.connect 'filter#filtered' => 'replicate#in'
  config.connect 'replicate#out[1]' => 'output1#in'
  config.connect 'replicate#out[2]' => 'output2#in'
  # Some tests that should fail
  # output should not have an 'out' ports
#  config.connect 'output#out' => 'simple#in'
end


