begin
  require 'em-zeromq'
rescue Exception => e
  raise LoadError, 'Error loading ZeroMQ; perhaps the wrong system library version is installed?'
end
require 'rflow/connection'
require 'rflow/message'
require 'rflow/broker'
require 'sys/filesystem'

class RFlow
  module Connections
    class ZMQConnection < RFlow::Connection
      class << self
        attr_accessor :zmq_context

        def create_zmq_context
          version = LibZMQ::version
          RFlow.logger.debug { "Creating a new ZeroMQ context; ZeroMQ version is #{version[:major]}.#{version[:minor]}.#{version[:patch]}" }
          if EM.reactor_running?
            raise RuntimeError, "EventMachine reactor is running when attempting to create a ZeroMQ context"
          end
          EM::ZeroMQ::Context.new(1)
        end

        # Returns the current ZeroMQ context object or creates it if it does not exist.
        def zmq_context
          @zmq_context ||= create_zmq_context
        end
      end

      def zmq_context; ZMQConnection.zmq_context; end

      private
      attr_accessor :input_socket, :output_socket

      public
      def initialize(config)
        super
        validate_options!
        zmq_context # cause the ZMQ context to be created before the reactor is running
      end

      def connect_input!
        RFlow.logger.debug "Connecting input #{uuid} with #{options.find_all {|k, v| k.to_s =~ /input/}}"
        check_address(options['input_address'])

        self.input_socket = zmq_context.socket(ZMQ.const_get(options['input_socket_type']))
        input_socket.send(options['input_responsibility'].to_sym, options['input_address'])
        if config.delivery == 'broadcast'
          input_socket.setsockopt(ZMQ::SUBSCRIBE, '') # request all messages
        end

        input_socket.on(:message) do |*message_parts|
          begin
            message = RFlow::Message.from_avro(message_parts.last.copy_out_string)
            RFlow.logger.debug "#{name}: Received message of type '#{message_parts.first.copy_out_string}'"
            message_parts.each(&:close) # avoid memory leaks
            recv_callback.call(message)
          rescue Exception => e
            RFlow.logger.error "#{name}: Exception processing message of type '#{message.data_type_name}': #{e.message}, because: #{e.backtrace}"
          end
        end

        input_socket
      end

      def connect_output!
        RFlow.logger.debug "Connecting output #{uuid} with #{options.find_all {|k, v| k.to_s =~ /output/}}"
        check_address(options['output_address'])

        self.output_socket = zmq_context.socket(ZMQ.const_get(options['output_socket_type']))
        output_socket.send(options['output_responsibility'].to_sym, options['output_address'].to_s)
        output_socket
      end

      # TODO: fix this tight loop of retries
      def send_message(message)
        RFlow.logger.debug "#{name}: Sending message of type '#{message.data_type_name.to_s}'"

        begin
          output_socket.send_msg(message.data_type_name.to_s, message.to_avro)
        rescue Exception => e
          RFlow.logger.debug "Exception #{e.class}: #{e.message}, retrying send"
          retry
        end
      end

      private
      def validate_options!
        # TODO: Normalize/validate configuration
        missing_options = []

        ['input', 'output'].each do |direction_prefix|
          ['_socket_type', '_address', '_responsibility'].each do |option_suffix|
            option_name = "#{direction_prefix}#{option_suffix}"
            unless options.include? option_name
              missing_options << option_name
            end
          end
        end

        unless missing_options.empty?
          raise ArgumentError, "#{self.class.to_s}: configuration missing options: #{missing_options.join ', '}"
        end

        true
      end

      def check_address(address)
        # make sure we're not trying to create IPC sockets in an NFS share
        # because that works poorly
        if address.start_with?('ipc://')
          filename = address[6..-1]
          mount_point = Sys::Filesystem.mount_point(File.dirname(filename))
          return unless mount_point
          mount_type = Sys::Filesystem.mounts.find {|m| m.mount_point == mount_point }.mount_type
          return unless mount_type

          case mount_type
          when 'vmhgfs', 'vboxsf', 'nfs' # vmware, virtualbox, nfs
            raise ArgumentError, "Cannot safely create IPC sockets in network filesystem '#{mount_point}' of type #{mount_type}"
          end
        end
      end
    end

    class BrokeredZMQConnection < ZMQConnection
    end

    # The broker process responsible for shuttling messages back and forth on a
    # many-to-many pipeline link. (Solutions without a broker only allow a
    # 1-to-many or many-to-1 connection.)
    class ZMQStreamer < Broker
      private
      attr_reader :connection, :context, :back, :front

      public
      def initialize(config)
        @connection = config.connection
        super("broker-#{connection.name}", 'Broker')
      end

      def run_process
        version = LibZMQ::version
        RFlow.logger.debug { "Creating a new ZeroMQ context; ZeroMQ version is #{version[:major]}.#{version[:minor]}.#{version[:patch]}" }
        @context = ZMQ::Context.new
        RFlow.logger.debug { "Connecting message broker to route from #{connection.options['output_address']} to #{connection.options['input_address']}" }

        @front = case connection.options['output_socket_type']
                 when 'PUSH'; context.socket(ZMQ::PULL)
                 when 'PUB'; context.socket(ZMQ::XSUB)
                 else raise ArgumentError, "Unknown output socket type #{connection.options['output_socket_type']}"
                 end
        @back = case connection.options['input_socket_type']
                when 'PULL'; context.socket(ZMQ::PUSH)
                when 'SUB'; context.socket(ZMQ::XPUB)
                else raise ArgumentError, "Unknown input socket type #{connection.options['input_socket_type']}"
                end
        front.bind(connection.options['output_address'])
        back.bind(connection.options['input_address'])
        ZMQ::Proxy.new(front, back)
        back.close
        front.close
      rescue Exception => e
        RFlow.logger.error "Error running message broker: #{e.class}: #{e.message}, because: #{e.backtrace.inspect}"
      ensure
        back.close if back
        front.close if front
        context.terminate if context
      end
    end
  end
end
