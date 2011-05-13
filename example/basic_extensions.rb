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

#RFlow::Configuration.add_available_data_schema RFlow::Message::Data::AvroSchema.new('Integer', long_integer_schema)

class SimpleDataExtension < RFlow::Message::Data
  puts "-----------------SimpleDataExtension"
end

puts "Before GenerateIntegerSequence"
class RFlow::Components::GenerateIntegerSequence < RFlow::Component
  output_port :out

  def configure!(config)
    @start = config[:start].to_i
    @finish = config[:finish].to_i
    @step = config[:step] ? config[:step].to_i : 1
    # If interval seconds is not given, it will default to 0
    @interval_seconds = config[:interval_seconds].to_i
  end

  # Note that this uses the timer (sometimes with 0 interval) so as
  # not to block the reactor
  def run!
    timer = EM::PeriodicTimer.new(@interval_seconds) do 
      out.send_message "#{self.class} '#{name}' (#{object_id}) sent #{@start}"
      @start += @step
      timer.cancel if @start > @finish
    end
  end
  
end

puts "Before Replicate"
class RFlow::Components::Replicate < RFlow::Component
  input_port :in
  output_port :out
  output_port :errored
  
  def process_message(input_port, input_port_key, connection, message)
    puts "Processing message in Replicate"
    out.each do |connections|
      puts "Replicating"
      begin
        connections.send_message message
      rescue Exception => e
        puts "Exception #{e.message}"
        errored.send_message message
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


