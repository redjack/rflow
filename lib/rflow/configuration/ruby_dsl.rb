require 'rflow/configuration'

class RFlow
  class Configuration

    # Ruby DSL config file controller.
    # TODO: more docs and examples
    class RubyDSL
      attr_accessor :settings, :components, :connections, :allocated_system_ports
      
      def initialize
        @settings = []
        @components = []
        @connections = []
      end

      # Generate a UUID based on either the SHA1 of a seed string (v5) with a
      # 'zero' UUID namespace, or using a purely random generation
      # (v4) if no seed string is present
      def generate_uuid_string(seed=nil)
        uuid = if seed
                 UUIDTools::UUID.sha1_create(UUIDTools::UUID.parse_int(0), seed)
               else
                 UUIDTools::UUID.random_create
               end
        uuid.to_s
      end

      # Helper function to extract the line of the config that
      # specified the operation.  Useful in printing helpful error messages
      def get_config_line(call_history)
        call_history.first.split(':in').first
      end
      
      # DSL method to specify a name/value pair.  RFlow core uses the
      # 'rflow.' prefix on all of its settings.  Custom settings
      # should use a custom (unique) prefix
      def setting(setting_name, setting_value)
        settings << {:name => setting_name, :value => setting_value, :config_line => get_config_line(caller)}
      end

      # DSL method to specify a component.  Expects a name,
      # specification, and set of component specific options, that
      # must be marshallable into the database (i.e. should all be strings)
      def component(component_name, component_specification, component_options={})
        components << {
          :uuid => generate_uuid_string(component_name), :name => component_name,
          :specification => component_specification.to_s, :options => component_options,
          :config_line => get_config_line(caller)
        }
      end

      # DSL method to specify a connection between a
      # component/output_port and another component/input_port.  The
      # component/port specification is a string where the names of
      # the two elements are separated by '#', and the "connection" is
      # specified by a Ruby Hash, i.e.:
      #  connect 'componentA#output' => 'componentB#input'
      # Array ports are specified with an index suffix in standard
      # progamming syntax, i.e.
      #  connect 'componentA#arrayport[2]' => 'componentB#in[1]'
      # Automatically generates component, port, and connection UUIDs.
      def connect(connection_hash)
        config_file_line = get_config_line(caller)
        connection_hash.each do |output_string, input_string|
          output_component_name, output_port_name = parse_connection_string(output_string)
          input_component_name, input_port_name = parse_connection_string(input_string)

          # TODO: Validation of input parameters for structure

          # TODO: break this out into individual methods for greater visibility
          # Generate the required UUIDs
          output_component_uuid = generate_uuid_string(output_component_name)
          output_port_uuid = generate_uuid_string(output_component_uuid + '#' + output_port_name)
          input_component_uuid = generate_uuid_string(input_component_name)
          input_port_uuid = generate_uuid_string(input_component_uuid + '#' + input_port_name)
          connection_uuid = generate_uuid_string(output_port_uuid + '=>' + input_port_uuid)
          
          connections << {
            :uuid => connection_uuid, :name => output_string + '=>' + input_string, 
            :output_component_uuid => output_component_uuid, :output_component_name => output_component_name,
            :output_port_uuid => output_port_uuid, :output_port_name => output_port_name, 
            :output_string => output_string,
            :input_component_uuid => input_component_uuid, :input_component_name => input_component_name,
            :input_port_uuid => input_port_uuid, :input_port_name => input_port_name, 
            :input_string => input_string,
            :config_line => config_file_line,
          }
        end
      end

      # Splits the connection string into component/port parts
      def parse_connection_string(connection_string)
        connection_string.split '#'
      end

      
      # Method to process the 'DSL' objects into the config database
      # via ActiveRecord
      def process
        process_settings
        process_components
        process_connections
      end

      
      # Iterates through each setting specified in the DSL and
      # creates rows in the database corresponding to the setting
      def process_settings
        settings.each do |setting|
          RFlow.logger.debug "Found config file setting '#{setting[:name]}' = (#{Dir.getwd}) '#{setting[:value]}'"
          RFlow::Configuration::Setting.create :name => setting[:name], :value => setting[:value]
        end
      end

      
      # Iterates through each component specified in the DSL and
      # creates rows in the database corresponding to the component.
      def process_components
        components.each do |component|
          RFlow.logger.debug "Found component '#{component[:name]}', creating"
          RFlow::Configuration::Component.create :uuid => component[:uuid], :name => component[:name], :specification => component[:specification], :options => component[:options]
        end
      end

      
      # Iterates through each component specified in the DSL and uses
      # 'process_connection' to insert all the parts of the connection
      # into the database
      def process_connections
        connections.each do |connection|
          process_connection(connection)
        end
      end

      # For the given connection, break up each input/output
      # component/port specification, ensure that the component
      # already exists in the database (by uuid).  Also, only supports
      # ZeroMQ ipc sockets
      def process_connection(connection)
        RFlow.logger.debug "Found connection from '#{connection[:output_string]}' to '#{connection[:input_string]}', creating"
        
        # an input port can be associated with multiple outputs, but
        # an output port can only be associated with one input
        output_component = RFlow::Configuration::Component.find_by_uuid connection[:output_component_uuid]
        raise RFlow::Configuration::Component::ComponentNotFound, "#{connection[:output_component_name]}" unless output_component
        # Do not allow an output to connect to multiple inputs, might throw a unique exception from ActiveRecord
        output_port = RFlow::Configuration::OutputPort.new :uuid => connection[:output_port_uuid], :name => connection[:output_port_name]
        output_component.output_ports << output_port
        output_port.save
        
        input_component = RFlow::Configuration::Component.find_by_uuid connection[:input_component_uuid]
        raise RFlow::Configuration::Component::ComponentNotFound, "#{connection[:input_component_name]}" unless input_component
        # Allow the same input to be connected to multiple outputs
        input_port = RFlow::Configuration::InputPort.find_or_initialize_by_uuid :uuid => connection[:input_port_uuid], :name => connection[:input_port_name]
        input_component.input_ports << input_port
        input_port.save

        # Generate a random port
        
        # Only support ZMQ ipc PUSH/PULL sockets at the moment
        connection = RFlow::Configuration::ZMQConnection.new(:uuid => connection[:uuid],
                                                             :name => connection[:name],
                                                             :options => {
                                                               :output_socket_type => 'PUSH',
                                                               :output_address => 'ipc://rflow.#{connection[:uuid]}',
                                                               :output_responsibility => 'bind',
                                                               :input_socket_type => 'PULL',
                                                               :input_address => 'ipc://rflow.#{connection[:uuid]}',
                                                               :input_responsibility => 'connect',
                                                             })

        connection.output_port = output_port
        connection.input_port = input_port
        connection.save

      rescue RFlow::Configuration::Component::ComponentNotFound => e
        error_message = "Component '#{e.message}' not found at #{connection[:config_line]}"
        RFlow.logger.error error_message
        raise RFlow::Configuration::Connection::ConnectionInvalid, error_message
      rescue Exception => e
        error_message = "Exception #{e.class} - '#{e.message}' at config '#{connection[:config_line]}'"
        RFlow.logger.error error_message
        raise RFlow::Configuration::Connection::ConnectionInvalid, error_message
      end

      
      # Method called within the config file itself
      def self.configure
        config_file = self.new
        yield config_file
        config_file.process
      end

    end # class RubyDSL
  end # class Configuration
end # class RFlow
