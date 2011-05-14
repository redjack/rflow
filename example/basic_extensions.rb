# This will/should bring in available components and their schemas
require 'rflow/components'
require 'rflow/message'

#RFlow::Configuration.add_available_data_schema RFlow::Message::Data::AvroSchema.new('Integer', long_integer_schema)

# Example of creating and registering a data extension
module SimpleDataExtension
  # Use this to default/verify the data in data_object
  def self.extended(base_data)
    base_data.data_object
  end

  def my_method; end
end
RFlow::Configuration.add_available_data_extension('RFlow::Message::Data::Integer', SimpleDataExtension)



# Example of creating and registering a new schema
long_integer_schema = '{"type": "long"}'
RFlow::Configuration.add_available_data_type('RFlow::Message::Data::Integer', :avro, long_integer_schema)


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
      message = RFlow::Message.new('RFlow::Message::Data::Integer')
      message.data.data_object = @start
      out.send_message message
      @start += @step
      timer.cancel if @start > @finish
    end
  end
  
end

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
    output_file.puts message.data.data_object.inspect
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


