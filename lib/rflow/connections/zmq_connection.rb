require 'ffi'
require 'ffi-rzmq'
require 'em-zeromq'

require 'rflow/connection'
require 'rflow/message'

class RFlow
  module Connections
    class ZMQConnection < RFlow::Connection

      class << self
        attr_accessor :zmq_context

        def create_zmq_context
          RFlow.logger.debug "Creating a new ZeroMQ context"
          unless EM.reactor_running?
            raise RuntimeError, "EventMachine reactor is not running when attempting to create a ZeroMQ context" 
          end
          EM::ZeroMQ::Context.new(1)
        end
        
        # Returns the current ZeroMQ context object or creates it if
        # it does not exist.  Assumes that we are within a running
        # EventMachine reactor
        def zmq_context
          @zmq_context ||= create_zmq_context
        end
      end

      attr_accessor :socket

      REQUIRED_OPTION_SUFFIXES = ['_socket_type', '_address', '_responsibility']

      def self.configuration_errors(configuration)
        # TODO: Normalize/validate configuration
        missing_config_elements = []

        ['input', 'output'].each do |direction_prefix|
          REQUIRED_OPTION_SUFFIXES.each do |option_suffix|
            config_element = "#{direction_prefix}#{option_suffix}"
            unless configuration.include? config_element
              missing_config_elements << config_element
            end
          end
        end

        missing_config_elements
      end

      
      def initialize(connection_instance_uuid, connection_name, connection_configuration)
        configuration_errors = self.class.configuration_errors(connection_configuration)
        unless configuration_errors.empty?
          raise ArgumentError, "#{self.class.to_s}: configuration missing elements: #{configuration_errors.join ', '}"
        end

        super
      end

      
      def connect_input!
        RFlow.logger.debug "Connecting input #{instance_uuid} with #{configuration.find_all {|k, v| k.to_s =~ /input/}}"
        self.socket = self.class.zmq_context.send(configuration['input_responsibility'],
                                                  ZMQ.const_get(configuration['input_socket_type'].to_sym),
                                                  configuration['input_address'],
                                                  self)
      end


      def connect_output!
        RFlow.logger.debug "Connecting output #{instance_uuid} with #{configuration.find_all {|k, v| k.to_s =~ /output/}}"
        self.socket = self.class.zmq_context.send(configuration['output_responsibility'].to_s,
                                                  ZMQ.const_get(configuration['output_socket_type'].to_sym),
                                                  configuration['output_address'].to_s,
                                                  self)
      end


      def on_readable(socket, message_parts)
        message = RFlow::Message.from_avro(message_parts.last.copy_out_string)
        RFlow.logger.debug "#{name} (#{object_id} => #{instance_uuid}): Received message of type '#{message_parts.first.copy_out_string}'"
        recv_callback.call(message)
      end

      # TODO: fix this tight loop of retries
      def send_message(message)
        RFlow.logger.debug "#{name} (#{object_id} => #{instance_uuid}): Sending message of type '#{message.data_type_name.to_s}'"

        begin
          socket.send_msg(message.data_type_name.to_s, message.to_avro)
          RFlow.logger.debug "#{name} (#{object_id} => #{instance_uuid}): Successfully sent message of type '#{message.data_type_name.to_s}'"
        rescue Exception => e
          RFlow.logger.debug "Exception #{e.class}: #{e.message}, retrying send"
          retry
        end
      end
      
    end
  end
end
