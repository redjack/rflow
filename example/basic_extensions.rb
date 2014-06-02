# This will/should bring in available components and their schemas
require 'rflow/components'
require 'rflow/message'

# Example of creating and registering a data extension
module SimpleDataExtension
  # Use this to default/verify the data in data_object
  def self.extended(base_data)
    base_data.data_object
  end

  def my_method; end
end
RFlow::Configuration.add_available_data_extension('RFlow::Message::Data::Integer', SimpleDataExtension)

class RFlow::Components::Replicate < RFlow::Component
  input_port :in
  output_port :out
  output_port :errored

  def process_message(input_port, input_port_key, connection, message)
    out.each do |connections|
      begin
        connections.send_message message
      rescue Exception => e
        errored.send_message message
      end
    end
  end
end

class RFlow::Components::RubyProcFilter < RFlow::Component
  input_port :in
  output_port :filtered
  output_port :dropped
  output_port :errored

  def configure!(config)
    @filter_proc = eval("lambda {|message| #{config['filter_proc_string']} }")
  end

  def process_message(input_port, input_port_key, connection, message)
    begin
      if @filter_proc.call(message)
        filtered.send_message message
      else
        dropped.send_message message
      end
    rescue Exception => e
      errored.send_message message
    end
  end
end

class RFlow::Components::FileOutput < RFlow::Component
  attr_accessor :output_file_path, :output_file
  input_port :in

  def configure!(config)
    self.output_file_path = config['output_file_path']
    self.output_file = File.new output_file_path, 'w+'
  end

  def process_message(input_port, input_port_key, connection, message)
    output_file.puts message.data.data_object.inspect
    output_file.flush
  end

  def cleanup
    output_file.close
  end
end

class SimpleComponent < RFlow::Component
  input_port :in
  output_port :out

  def configure!(config); end
  def run!; end
  def process_message(input_port, input_port_key, connection, message); end
  def shutdown!; end
  def cleanup!; end
end
