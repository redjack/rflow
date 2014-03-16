# This will/should bring in available components and their schemas
require 'rflow/components'
require 'rflow/message'


class RFlow::Components::Replicate < RFlow::Component
  input_port :in
  output_port :out
  output_port :errored

  def process_message(input_port, input_port_key, connection, message)
    out.each do |connections|
      begin
        connections.send_message message
      rescue Exception => e
        RFlow.logger.debug "#{self.class} Message caused exception: #{e.class}: #{e.message}: #{e.backtrace}"
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
    RFlow.logger.debug "Filtering message"
    begin
      if @filter_proc.call(message)
        filtered.send_message message
      else
        dropped.send_message message
      end
    rescue Exception => e
      RFlow.logger.debug "#{self.class} Message caused exception: #{e.class}: #{e.message}: #{e.backtrace}"
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

  def cleanup!
    output_file.close
  end
end

# TODO: Ensure that all the following methods work as they are
# supposed to.  This is the interface that I'm adhering to
class SimpleComponent < RFlow::Component
  input_port :in
  output_port :out

  def configure!(config); end
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
RFlow::Configuration.add_available_data_type('HTTPRequest', 'avro', http_request_schema)

http_response_schema =<<EOS
{
    "type": "record",
    "name": "HTTPResponse",
    "namespace": "org.rflow",
    "aliases": [],
    "fields": [
        {"name": "status", "type": "int"},
        {"name": "content", "type": "bytes"}
    ]
}
EOS
RFlow::Configuration.add_available_data_type('HTTPResponse', 'avro', http_response_schema)


# Need to be careful when extending to not clobber data already in data_object
module HTTPRequestExtension
  def self.extended(base_data)
    base_data.data_object ||= {'path' => ''}
  end

  def path; data_object['path']; end
  def path=(new_path); data_object['path'] = new_path; end
end
RFlow::Configuration.add_available_data_extension('HTTPRequest', HTTPRequestExtension)


# Need to be careful when extending to not clobber data already in data_object
module HTTPResponseExtension
  def self.extended(base_data)
    base_data.data_object ||= {'status' => 200, 'content' => ''}
  end

  def status; data_object['status']; end
  def status=(new_status); data_object['status'] = new_status; end

  def content; data_object['content']; end
  def content=(new_content); data_object['content'] = new_content; end
end
RFlow::Configuration.add_available_data_extension('HTTPResponse', HTTPResponseExtension)


require 'eventmachine'
require 'evma_httpserver'

class HTTPServer < RFlow::Component
  input_port :response_port
  output_port :request_port

  attr_accessor :port, :listen, :server_signature, :connections

  def configure!(config)
    @listen = config['listen'] ? config['listen'] : '127.0.0.1'
    @port = config['port'] ? config['port'].to_i : 8000
    @connections = Hash.new
  end

  def run!
    @server_signature = EM.start_server(@listen, @port, Connection) do |conn|
      conn.server = self
      self.connections[conn.signature.to_s] = conn
    end
  end

  # Getting all messages to response_port, which we need to filter for
  # those that pertain to this component and have active connections.
  # This is done by inspecting the provenance, specifically the
  # context attribute that we stored originally
  def process_message(input_port, input_port_key, connection, message)
    RFlow.logger.debug "Received a message"
    return unless message.data_type_name == 'HTTPResponse'

    RFlow.logger.debug "Received a HTTPResponse message, determining if its mine"
    my_events = message.provenance.find_all {|processing_event| processing_event.component_instance_uuid == instance_uuid}
    RFlow.logger.debug "Found #{my_events.size} processing events from me"
    # Attempt to send the data to each context match
    my_events.each do |processing_event|
      RFlow.logger.debug "Inspecting #{processing_event.context}"
      ip, port, connection_signature = processing_event.context.split ':'
      if connections[connection_signature]
        RFlow.logger.debug "Found connection for #{processing_event.context}"
        connections[connection_signature].send_http_response message
      end
    end
  end

  class Connection < EventMachine::Connection
    include EventMachine::HttpServer

    attr_accessor :server, :client_ip, :client_port

    def post_init
      @client_port, @client_ip = Socket.unpack_sockaddr_in(get_peername) rescue ["?", "?.?.?.?"]
      RFlow.logger.debug "Connection from #{@client_ip}:#{@client_port}"
      super
      no_environment_strings
    end


    def receive_data(data)
      RFlow.logger.debug "Received #{data.bytesize} data from #{client_ip}:#{client_port}"
      super
    end


    def process_http_request
      RFlow.logger.debug "Received a full HTTP request from #{client_ip}:#{client_port}"

      processing_event = RFlow::Message::ProcessingEvent.new(server.instance_uuid, Time.now.utc)

      request_message = RFlow::Message.new('HTTPRequest')
      request_message.data.path = @http_request_uri

      processing_event.context = "#{client_ip}:#{client_port}:#{signature}"
      processing_event.completed_at = Time.now.utc
      request_message.provenance << processing_event

      server.request_port.send_message request_message
    end


    def send_http_response(response_message=nil)
      RFlow.logger.debug "Sending an HTTP response to #{client_ip}:#{client_port}"
      resp = EventMachine::DelegatedHttpResponse.new(self)

      # Default values
      resp.status                  = 200
      resp.content                 = ""
      resp.headers["Content-Type"] = "text/html; charset=UTF-8"
      resp.headers["Server"]       = "Apache/2.2.3 (CentOS)"

      if response_message
        resp.status  = response_message.data.status
        resp.content = response_message.data.content
      end

      resp.send_response
      close_connection_after_writing
    end


    # Called when a connection is torn down for whatever reason.
    # Remove this connection from the server's list
    def unbind
      RFlow.logger.debug "Connection to lost"
      server.connections.delete(self.signature)
    end
  end
end

# As this component creates a new message type based on another, it
# copies over the provenance.  It does not bother to add its own
# processing_event to the provenance, but it could/should
class HTTPResponder < RFlow::Component
  input_port :request
  output_port :response

  def process_message(input_port, input_port_key, connection, message)
    response_message = RFlow::Message.new('HTTPResponse')
    response_message.data.status = 404
    response_message.data.content = "CONTENT: #{message.data.path} was accessed"
    response_message.provenance = message.provenance
    response.send_message response_message
  end
end

