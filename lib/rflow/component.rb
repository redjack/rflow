require 'rflow/message'
require 'rflow/component/port'

class RFlow
  class Component
    # Keep track of available component subclasses
    def self.inherited(subclass)
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
        collection[port_name.to_s] = true

        # Create the port accessor method based on the port name
        define_method port_name.to_s.to_sym do
          port = ports.by_name[port_name.to_s]
          return port if port

          # If the port was not connected, return a port-like object
          # that can respond/log but doesn't send any data.  Note,
          # it won't be available in the 'by_uuid' collection, as it
          # doesn't have a configured instance_uuid
          RFlow.logger.debug "'#{self.name}##{port_name}' not connected, creating a disconnected port"
          disconnected_port = DisconnectedPort.new(port_name, 0)
          ports << disconnected_port
          disconnected_port
        end
      end


      # Attempt to instantiate a component described by the config
      # specification. This assumes that the specification of a
      # component is a fully qualified Ruby class that has already
      # been loaded. It will first attempt to find subclasses of
      # RFlow::Component (in the available_components hash) and then
      # attempt to constantize the specification into a different
      # class. Future releases will support external (i.e. non-managed
      # components), but the current stuff only supports Ruby classes
      def build(config)
        if config.managed?
          RFlow.logger.debug "Instantiating component '#{config.name}' as '#{config.specification}' (#{config.uuid})"
          begin
            RFlow.logger.debug RFlow.configuration.available_components.inspect
            instantiated_component = if RFlow.configuration.available_components.include? config.specification
                                       RFlow.logger.debug "Component found in configuration.available_components['#{config.specification}']"
                                       RFlow.configuration.available_components[config.specification].new(config)
                                     else
                                       RFlow.logger.debug "Component not found in configuration.available_components, constantizing component '#{config.specification}'"
                                       config.specification.constantize.new(config)
                                     end
          rescue NameError => e
            error_message = "Could not instantiate component '#{config.name}' as '#{config.specification}' (#{config.uuid}): the class '#{config.specification}' was not found"
            RFlow.logger.error error_message
            raise RuntimeError, error_message
          rescue Exception => e
            error_message = "Could not instantiate component '#{config.name}' as '#{config.specification}' (#{config.uuid}): #{e.class} #{e.message}"
            RFlow.logger.error error_message
            raise RuntimeError, error_message
          end
        else
          error_message = "Non-managed components not yet implemented for component '#{config.name}' as '#{config.specification}' (#{config.uuid})"
          RFlow.logger.error error_message
          raise NotImplementedError, error_message
        end

        instantiated_component
      end
    end

    attr_reader :instance_uuid
    attr_reader :name
    attr_reader :config
    attr_reader :ports

    def initialize(config)
      @instance_uuid = config.uuid
      @name = config.name
      @ports = PortCollection.new
      @config = config

      configure_ports!
      configure_connections!
      configure!(config.options)
    end


    # Returns a list of connected input ports.  Each port will have
    # one or more keys associated with a particular connection.
    def input_ports
      ports.by_type["RFlow::Component::InputPort"]
    end


    # Returns a list of connected output ports.  Each port will have
    # one or more keys associated with the particular connection.
    def output_ports
      ports.by_type["RFlow::Component::OutputPort"]
    end


    # Returns a list of disconnected output ports.
    def disconnected_ports
      ports.by_type["RFlow::Component::DisconnectedPort"]
    end


    def configure_ports!
      # Send the port configuration to each component
      config.input_ports.each do |input_port_config|
        RFlow.logger.debug "Configuring component '#{name}' (#{instance_uuid}) with input port '#{input_port_config.name}' (#{input_port_config.uuid})"
        configure_input_port!(input_port_config.name, input_port_config.uuid)
      end

      config.output_ports.each do |output_port_config|
        RFlow.logger.debug "Configuring component '#{name}' (#{instance_uuid}) with output port '#{output_port_config.name}' (#{output_port_config.uuid})"
        configure_output_port!(output_port_config.name, output_port_config.uuid)
      end
    end


    def configure_input_port!(port_name, port_instance_uuid, port_options={})
      unless self.class.defined_input_ports.include? port_name
        raise ArgumentError, "Input port '#{port_name}' not defined on component '#{self.class}'"
      end
      ports << InputPort.new(port_name, port_instance_uuid, port_options)
    end


    def configure_output_port!(port_name, port_instance_uuid, port_options={})
      unless self.class.defined_output_ports.include? port_name
        raise ArgumentError, "Output port '#{port_name}' not defined on component '#{self.class}'"
      end
      ports << OutputPort.new(port_name, port_instance_uuid, port_options)
    end


    def configure_connections!
      config.input_ports.each do |input_port_config|
        input_port_config.input_connections.each do |input_connection_config|
          RFlow.logger.debug "Configuring input port '#{input_port_config.name}' (#{input_port_config.uuid}) key '#{input_connection_config.input_port_key}' with #{input_connection_config.type.to_s} connection '#{input_connection_config.name}' (#{input_connection_config.uuid})"
          configure_connection!(input_port_config.uuid, input_connection_config.input_port_key,
                                input_connection_config.type, input_connection_config.uuid, input_connection_config.name, input_connection_config.options)
        end
      end

      config.output_ports.each do |output_port_config|
        output_port_config.output_connections.each do |output_connection_config|
          RFlow.logger.debug "Configuring output port '#{output_port_config.name}' (#{output_port_config.uuid}) key '#{output_connection_config.output_port_key}' with #{output_connection_config.type.to_s} connection '#{output_connection_config.name}' (#{output_connection_config.uuid})"
          configure_connection!(output_port_config.uuid, output_connection_config.output_port_key,
                                output_connection_config.type, output_connection_config.uuid, output_connection_config.name, output_connection_config.options)
        end
      end
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

      ports.by_uuid[port_instance_uuid.to_s].add_connection(port_key, connection)
      connection
    end


    # Tell the component to establish it's ports' connections, i.e. make
    # the connection.  Uses the underlying connection object.  Also
    # establishes the callbacks for each of the input ports
    def connect!
      input_ports.each do |input_port|
        input_port.connect!

        # Create the callbacks for recieving messages as a proc
        input_port.keys.each do |input_port_key|
          keyed_connections = input_port[input_port_key]
          keyed_connections.each do |connection|
            connection.recv_callback = Proc.new do |message|
              process_message(input_port, input_port_key, connection, message)
            end
          end
        end
      end

      output_ports.each do |output_port|
        output_port.connect!
      end
    end


    def to_s
      string = "Component '#{name}' (#{instance_uuid})\n"
      ports.each do |port|
        port.keys.each do |port_key|
          port[port_key].each do |connection|
            string << "\t#{port.class.to_s} '#{port.name}' (#{port.instance_uuid}) key '#{port_key}' connection '#{connection.name}' (#{connection.instance_uuid})\n"
          end
        end
      end
      string
    end


    # Method that should be overridden by a subclass to provide for
    # component-specific configuration.  The subclass should use the
    # self.configuration attribute (@configuration) to store its
    # particular configuration.  The incoming deserialized_configuration
    # parameter is from the RFlow configuration database and is (most
    # likely) a hash.  Don't assume that the keys are symbols
    def configure!(deserialized_configuration); end

    # Main component running method.  Subclasses should implement if
    # they want to set up any EventMachine stuffs (servers, clients,
    # etc)
    def run!; end

    # Method called when a message is received on an input port.
    # Subclasses should implement if they want to receive messages
    def process_message(input_port, input_port_key, connection, message); end

    # Method called when RFlow is shutting down.  Subclasses should
    # implment to terminate any servers/clients (or let them finish)
    # and stop sending new data through the flow
    def shutdown!; end

    # Method called after all components have been shutdown! and just
    # before the global RFlow exit.  Sublcasses should implement to
    # cleanup any leftover state, e.g. flush file handles, etc
    def cleanup!; end

  end # class Component
end # class RFlow
