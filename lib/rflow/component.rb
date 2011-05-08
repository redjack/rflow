require 'rflow/message'

class RFlow
  class Component
    # Keep track of available component subclasses
    def self.inherited(subclass)
      RFlow.logger.debug "Found component #{subclass.name}"
      RFlow::Configuration.add_available_component(subclass)
    end

    class Port; end
    
    class HashPort < Port
      attr_reader :name, :connections
      
      def initialize(name)
        @name = name
        @connections = []
      end

      def [](key=:"0")
        connections[key.to_s.to_sym || :"0"]
      end

      def each
        # Use the delegate functionality
      end
      
      def send_message(message, port_key=0)
        error_message = "send_message not implemented for #{self.inspect}"
        RFlow.logger.error error_message
        raise NotImplementedError, error_message
      end

      def recv_message(message, port_key=0)
        error_message = "recv_message not implemented for #{self.inspect}"
        RFlow.logger.error error_message
        raise NotImplementedError, error_message
      end
    end

    class InputPort < HashPort
      # TODO: Needs some poll/timeout love
      def recv_message(message, port_key=0)
        connections[port_key].recv_message(message)
      end
    end

    class OutputPort < HashPort
      def send_message(message, port_key=0)
        connections[port_key].send_message(message)
      end
    end
    
        
    # The class methods used in the creation of a component
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
      def input_port(name)
        define_port(defined_input_ports, InputPort, name)
      end

      # Define an output port with a given name
      def output_port(name)
        define_port(defined_output_ports, OutputPort, name)
      end

      # Helper method to keep things DRY for standard component
      # definition methods input_port and output_port
      def define_port(collection, klass, name)
        name_sym = name.to_sym
        collection[name_sym] = klass

        # Create the port accessor method based on the port name
        define_method name_sym do |*args|
          key = args.first.to_s.to_sym || 0.to_s.to_sym
          puts "defining a port method #{name} at called"
          self.ports[name]
        end
      end
    end

    attr_reader :instance_uuid
    attr_reader :config
    attr_reader :ports
    
    def initialize(uuid, config)
      @instance_uuid = uuid
      @config = config
      @ports = Hash.new
    end


    # A connection_config should look shockingly similar to an
    # RFlow::Configuration::Connection, i.e. what is stored in the
    # configuration database.  Eventually, we'll make this taskable
    # via the management interface, but right now it assumes single
    # process.
    def configure_connections(connection_configs)
      connection_configs.each do |connection_config|
        # Lookup the port by UUID for both input and output
        # create the connection, either input or output
        # install the connection for the given port and index
      end
    end

      
    def configure_component
    end


    # TODO: Fix this stuffs
    def connect_input(port_name, port_key, connection)
      connect(InputPort, port_name, port_key, connection)
    end

    def connect_output(port_name, port_key, connection)
      connect(OutputPort, port_name, port_key, connection)
    end
    
    def connect(port_class, port_name, port_key, connection)
      port_sym = port_name.to_sym
      unless ports[port_sym]
        port = port_class.new(port_name)
        port.connect(port_key, connection)
        ports[port_sym] = port
      end
    end
    
    # Do stuff related before the process_message subclass method is called
    def pre_process_message(input_port, message)
      # Start updating the provenance with the start time
    end
    
    # Designed to be abstract
    def process_message(input_port, message); end
    
    # Do stuff related after the process_message subclass method is called
    def post_process_message(input_port, message); end
    
    # Main component running method.  Called 
    def run
      select(input_ports, output_ports) do |ready|
        if ready.input?
          message = read_message(ready)
          pre_process_message(ready_message)
          process_message(ready, message)
          post_process_message(ready, message)
        elsif ready.output?
        end
      end
      
    end
    
  end # class Component
end # class RFlow
