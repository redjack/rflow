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

class RFlow::Components::FileOutput < RFlow::Component
  attr_accessor :output_file_path
  input_port :in

  def configure!(config)
    self.output_file_path = config['output_file_path']
  end

  def process_message(input_port, input_port_key, connection, message)
    File.open(output_file_path, 'a') do |f|
      f.flock(File::LOCK_EX)
      f.puts message.data.data_object.inspect
      f.flush
      f.flock(File::LOCK_UN)
    end
  end
end

class RFlow::Components::DateShellComponent < RFlow::Component
  input_port :in
  output_port :out

  def configure!(config); end
  def run!; end
  def process_message(input_port, input_port_key, connection, message)
    out.send_message(
      RFlow::Message.new('RFlow::Message::Data::Raw').tap do |m|
        m.provenance = message.provenance
        m.data.raw = `date`
      end)
  end
  def shutdown!; end
  def cleanup!; end
end
