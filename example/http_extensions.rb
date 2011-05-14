# This will/should bring in available components and their schemas
require 'rflow/components'
require 'rflow/message'


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
    @filter_proc = eval("lambda {|message| #{deserialized_configuration[:filter_proc_string]} }")
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


class RFlow::Components::FileOutput < RFlow::Component
  attr_accessor :output_file_path, :output_file
  input_port :in

  def configure!(deserialized_configuration)
    self.output_file_path = deserialized_configuration[:output_file_path]
    self.output_file = File.new output_file_path, 'w+'
  end

  def process_message(input_port, input_port_key, connection, message)
    puts "About to output to a file #{output_file_path}"
    output_file.puts message.data.data_object.inspect
  end
  
  def cleanup!
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


http_request_schema =<<EOS
{
    "type": "record",
    "name": "HTTPRequest",
    "namespace": "org.rflow",
    "aliases": [],
    "fields": [
        {"name": "path", "type": "string"}
    ]
}
EOS
RFlow::Configuration.add_available_data_type('HTTPRequest', :avro, http_request_schema)


module HTTPRequestExtension 
  def self.extended(base_data)
    base_data.data_object = {'path' => ''}
  end

  def path; data_object['path']; end
  def path=(new_path); data_object['path'] = new_path; end
end
RFlow::Configuration.add_available_data_extension('HTTPRequest', HTTPRequestExtension)


require 'eventmachine'
require 'evma_httpserver'

class HTTPServer < RFlow::Component
  input_port :response
  output_port :request

  attr_accessor :port, :listen, :server_signature, :connections
  
  def configure!(config_hash)
    @listen = config_hash[:listen] ? config_hash[:listen] : '127.0.0.1'
    @port = config_hash[:port] ? config_hash[:port].to_i : 8100
    @connections = []
  end

  def run!
    @server_signature = EM.start_server(@listen, @port, Connection) do |conn|
      puts "Assigning server to #{conn.inspect}"
      conn.server = self
    end
  end

  class Connection < EventMachine::Connection
    include EventMachine::HttpServer

    attr_accessor :server

    def post_init
      puts "Post init"
      p server
      server.connections << self
    end
    
    def process_http_request
      RFlow.logger.debug "Got an http request"
      message = RFlow::Message.new('HTTPRequest')
      message.data.path = @http_request_uri
      server.request.send_message message
    end

    def unbind
      server.connections.delete(self)
    end
  end
end

class HTTPResponder < RFlow::Component
  input_port :request
  output_port :response
end

