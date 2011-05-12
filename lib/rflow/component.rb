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
          puts "defining a port method #{port_name}[#{key}] called"
          # HACK: (Slowly) lookup the port in the available UUID-keyed
          # hash.  Think about keeping a name-keyed hash as well.
          # Profile later.
          port = self.ports.values.find do |port|
            port.name.to_sym == port_name_sym
          end

          raise ArgumentError, "#{self.class.to_s}: Invalid port '#{port_name}' accessed" unless port

          port[key]
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
      @ports = Hash.new
      @configuration = configuration
    end


    def configure!(configuration)
      @configuration = configuration
    end
    
    # TODO: DRY up the following two methods by factoring out into a meta-method
    
    def configure_input_port!(port_name, port_instance_uuid, port_options={})
      unless self.class.defined_input_ports.include? port_name.to_sym
        raise ArgumentError, "Input port '#{port_name}' not defined on this component"
      end
      input_port = InputPort.new(port_name, port_instance_uuid, port_options)
      ports[port_instance_uuid.to_sym] = input_port
      input_port
    end

    
    def configure_output_port!(port_name, port_instance_uuid, port_options={})
      unless self.class.defined_output_ports.include? port_name.to_sym
        raise ArgumentError, "Output port '#{port_name}' not defined on this component"
      end
      output_port = OutputPort.new(port_name, port_instance_uuid, port_options)
      ports[port_instance_uuid.to_sym] = output_port
      output_port
    end


    # Only supports Ruby types.
    # TODO: figure out how to dynamically load the built-in
    # connections, or require them at the top of the file and not rely
    # on rflow.rb requiring 'rflow/connections'
    def configure_connection!(port_instance_uuid, port_key, connection_type, connection_uuid, connection_options={})
      case connection_type
      when 'RFlow::Configuration::ZMQConnection'
        connection = RFlow::Connections::ZMQConnection.new(connection_uuid, connection_options)
      else
        raise ArgumentError, "Only ZMQConnections currently supported"
      end

      ports[port_instance_uuid.to_sym][port_key] = connection
      connection
    end

    
    # Tell the component to establish its ports connections, i.e. make
    # the connection.  Uses the underlying connection object
    def connect!
      ports.each do |port_instance_uuid, port|
        port.connect!
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
    def run!
#      select(input_ports, output_ports) do |ready|
#        if ready.input?
#          message = read_message(ready)
#          pre_process_message(ready_message)
#          process_message(ready, message)
#          post_process_message(ready, message)
#        elsif ready.output?
#        end
#      end
    end
    
  end # class Component
end # class RFlow
