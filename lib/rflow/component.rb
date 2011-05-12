require 'rflow/message'
require 'rflow/component/port'

class RFlow
  class Component
    # Keep track of available component subclasses
    def self.inherited(subclass)
      RFlow.logger.debug "Found component #{subclass.name}"
      RFlow::Configuration.add_available_component(subclass)
    end

        
    # The Component class methods used in the creation of a component
    class << self
      def defined_input_ports
        @defined_input_ports ||= Hash.new
      end

      def defined_output_ports
        @defined_output_ports ||= Hash.new
      end

      # TODO: Update the class vs instance stuffs here to be correct
      # Port defintions only have names

      # TODO: consider class-based UUIDs to identify component types
      
      # Define an input port with a given name
      def input_port(port_name)
        define_port(defined_input_ports, port_name)
      end

      # Define an output port with a given name
      def output_port(port_name)
        define_port(defined_output_ports, port_name)
      end

      # Helper method to keep things DRY for standard component
      # definition methods input_port and output_port
      def define_port(collection, port_name)
        port_name_sym = port_name.to_sym
        collection[port_name_sym] = true

        # Create the port accessor method based on the port name
        define_method port_name_sym do |*args|
          key = args.first ? args.first.to_s.to_sym : 0.to_s.to_sym

          port = ports.by_name[port_name_sym] 

          if port
            port[key]
          else
            # If the port was not connected, return a port-like object
            # that can respond/log but doesn't send any data.  Note,
            # it won't be available in the 'by_uuid' collection, as it
            # doesn't have a configured instance_uuid
            RFlow.logger.debug "'#{name}##{port_name}' not connected, creating a disconnected port"
            disconnected_port = DisconnectedPort.new(port_name, 0)
            disconnected_port[key] << Disconnection.new(0)
            ports << disconnected_port
            disconnected_port[key]
          end
        end
      end
    end

    attr_reader :instance_uuid
    attr_reader :name
    attr_reader :configuration
    attr_reader :ports
    
    def initialize(uuid, name=nil, configuration=nil)
      @instance_uuid = uuid
      @name = name.to_sym
      @ports = PortCollection.new
      @configuration = configuration
    end

    
    # Returns a list of connected input ports.  Each port will have
    # one or more keys associated with a particular connection.
    def input_ports
      ports.by_type[:"RFlow::Component::InputPort"]
    end

    
    # Returns a list of connected output ports.  Each port will have
    # one or more keys associated with the particular connection.
    def output_ports
      ports.by_type[:"RFlow::Component::OutputPort"]
    end

    
    # Returns a list of disconnected output ports.
    def disconnected_ports
      ports.by_type[:"RFlow::Component::DisconnectedPort"]
    end
    

    # Method that should be overridden by a subclass to provide for
    # component-specific configuration.  The subclass should use the
    # self.configuration attribute (@configuration) to store its
    # particular configuration.  The incoming deserialized_configuration
    # parameter is from the RFlow configuration database and is (most
    # likely) a hash.  Don't assume that the keys are symbols
    def configure!(deserialized_configuration); end
    
    
    # TODO: DRY up the following two methods by factoring out into a meta-method
    
    def configure_input_port!(port_name, port_instance_uuid, port_options={})
      unless self.class.defined_input_ports.include? port_name.to_sym
        raise ArgumentError, "Input port '#{port_name}' not defined on this component"
      end
      ports <<  InputPort.new(port_name, port_instance_uuid, port_options)
    end

    
    def configure_output_port!(port_name, port_instance_uuid, port_options={})
      unless self.class.defined_output_ports.include? port_name.to_sym
        raise ArgumentError, "Output port '#{port_name}' not defined on this component"
      end
      ports << OutputPort.new(port_name, port_instance_uuid, port_options)
    end


    # Only supports Ruby types.
    # TODO: figure out how to dynamically load the built-in
    # connections, or require them at the top of the file and not rely
    # on rflow.rb requiring 'rflow/connections'
    def configure_connection!(port_instance_uuid, port_key, connection_type, connection_uuid, connection_name=nil, connection_options={})
      case connection_type
      when 'RFlow::Configuration::ZMQConnection'
        connection = RFlow::Connections::ZMQConnection.new(connection_uuid, connection_name, connection_options)
      else
        raise ArgumentError, "Only ZMQConnections currently supported"
      end

      ports.by_uuid[port_instance_uuid.to_s.to_sym][port_key] << connection
      connection
    end

    
    # Tell the component to establish it's ports' connections, i.e. make
    # the connection.  Uses the underlying connection object.  Also
    # establishes the callbacks for each of the input ports
    def connect!
      input_ports.each do |input_port|
        input_port.connect!

        # Create the callbacks for recieveing messages as a proc
        input_port.keys.each do |input_port_key|
          scoped_connections = input_port[input_port_key]
          scoped_connections.each do |connection|
            connection.recv_callback = Proc.new do |message|
              pre_process_message(input_port, input_port_key, connection, message)
              process_message(input_port, input_port_key, connection, message)
              post_process_message(input_port, input_port_key, connection, message)
            end
          end
        end
      end
        
      output_ports.each do |output_port|
        output_port.connect!
      end
    end

    
    # Do stuff related before the process_message subclass method is called
    def pre_process_message(input_port, input_port_key, connection, message)
      # Start updating the provenance with the start time
    end
    
    # Designed to be abstract
    def process_message(input_port, input_port_key, connection, message)
      puts "#{self.class} Processing message from '#{input_port.name}' (#{input_port.instance_uuid}): '#{message}'"
    end
    
    # Do stuff related after the process_message subclass method is called
    def post_process_message(input_port, input_port_key, connection, message)
    end
    
    # Main component running method.
    def run!; end

    def to_s
      string = "Component '#{name}' (#{instance_uuid})\n"
      ports.each do |port|
        p port
        port.keys.each do |port_key|
          p port_key
          port[port_key].each do |connection|
            p connection
            string << "\t#{port.class.to_s} '#{port.name}' (#{port.instance_uuid}) key '#{port_key}' connection '#{connection.name}' (#{connection.instance_uuid})\n"
          end
        end
      end
      string
    end
    
  end # class Component
end # class RFlow
