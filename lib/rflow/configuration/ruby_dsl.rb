require 'rflow/configuration'

class RFlow
  class Configuration

    # Ruby DSL config file controller.
    # TODO: more docs and examples
    class RubyDSL
      attr_accessor :setting_specs, :component_specs, :connection_specs, :allocated_system_ports

      def initialize
        @setting_specs = []
        @component_specs = []
        @connection_specs = []
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
        setting_specs << {:name => setting_name.to_s, :value => setting_value.to_s, :config_line => get_config_line(caller)}
      end

      # DSL method to specify a component.  Expects a name,
      # specification, and set of component specific options, that
      # must be marshallable into the database (i.e. should all be strings)
      def component(component_name, component_specification, component_options={})
        component_specs << {
          :name => component_name,
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
      # Array ports are specified with an key suffix in standard
      # progamming syntax, i.e.
      #  connect 'componentA#arrayport[2]' => 'componentB#in[1]'
      # Uses the model to assign random UUIDs
      def connect(connection_hash)
        config_file_line = get_config_line(caller)
        connection_hash.each do |output_string, input_string|
          output_component_name, output_port_name, output_port_key = parse_connection_string(output_string)
          input_component_name, input_port_name, input_port_key = parse_connection_string(input_string)

          connection_specs << {
            :name => output_string + '=>' + input_string,
            :output_component_name => output_component_name,
            :output_port_name => output_port_name, :output_port_key => output_port_key,
            :output_string => output_string,
            :input_component_name => input_component_name,
            :input_port_name => input_port_name, :input_port_key => input_port_key,
            :input_string => input_string,
            :config_line => config_file_line,
          }
        end
      end

      # Splits the connection string into component/port parts
      COMPONENT_PORT_STRING_REGEX = /^(\w+)#(\w+)(?:\[([^\]]+)\])?$/
      def parse_connection_string(connection_string)
        matched = COMPONENT_PORT_STRING_REGEX.match(connection_string)
        raise ArgumentError, "Invalid component/port string specification: #{connection_string}" unless matched
        # component_name, port_name, port_key
        [matched[1], matched[2], (matched[3] || nil)]
      end


      # Method to process the 'DSL' objects into the config database
      # via ActiveRecord
      def process
        process_setting_specs
        process_component_specs
        process_connection_specs
      end


      # Iterates through each setting specified in the DSL and
      # creates rows in the database corresponding to the setting
      def process_setting_specs
        setting_specs.each do |setting_spec|
          RFlow.logger.debug "Found config file setting '#{setting_spec[:name]}' = (#{Dir.getwd}) '#{setting_spec[:value]}'"
          RFlow::Configuration::Setting.create! :name => setting_spec[:name], :value => setting_spec[:value]
        end
      end


      # Iterates through each component specified in the DSL and
      # creates rows in the database corresponding to the component.
      def process_component_specs
        component_specs.each do |component_spec|
          RFlow.logger.debug "Found component '#{component_spec[:name]}', creating"
          RFlow::Configuration::Component.create! :name => component_spec[:name], :specification => component_spec[:specification], :options => component_spec[:options]
        end
      end


      # Iterates through each component specified in the DSL and uses
      # 'process_connection' to insert all the parts of the connection
      # into the database
      def process_connection_specs
        connection_specs.each do |connection_spec|
          process_connection_spec(connection_spec)
        end
      end

      # For the given connection, break up each input/output
      # component/port specification, ensure that the component
      # already exists in the database (by name).  Also, only supports
      # ZeroMQ ipc sockets
      def process_connection_spec(connection_spec)
        RFlow.logger.debug "Found connection from '#{connection_spec[:output_string]}' to '#{connection_spec[:input_string]}', creating"

        # an input port can be associated with multiple outputs, but
        # an output port can only be associated with one input
        output_component = RFlow::Configuration::Component.find_by_name connection_spec[:output_component_name]
        raise RFlow::Configuration::Component::ComponentNotFound, "#{connection_spec[:output_component_name]}" unless output_component
        output_port = output_component.output_ports.find_or_initialize_by_name :name => connection_spec[:output_port_name]
        output_port.save!

        input_component = RFlow::Configuration::Component.find_by_name connection_spec[:input_component_name]
        raise RFlow::Configuration::Component::ComponentNotFound, "#{connection_spec[:input_component_name]}" unless input_component
        input_port = input_component.input_ports.find_or_initialize_by_name :name => connection_spec[:input_port_name]
        input_port.save!

        connection = RFlow::Configuration::ZMQConnection.new(:name => connection_spec[:name],
                                                             :output_port_key => connection_spec[:output_port_key],
                                                             :input_port_key => connection_spec[:input_port_key])

        connection.output_port = output_port
        connection.input_port = input_port
        connection.save!

      rescue RFlow::Configuration::Component::ComponentNotFound => e
        error_message = "Component '#{e.message}' not found at #{connection_spec[:config_line]}"
        RFlow.logger.error error_message
        raise RFlow::Configuration::Connection::ConnectionInvalid, error_message
      rescue Exception => e
        # TODO: Figure out why an ArgumentError doesn't put the
        # offending message into e.message, even though it is printed
        # out if not caught
        error_message = "#{e.class}: #{e.message} at config '#{connection_spec[:config_line]}'"
        RFlow.logger.debug "Exception #{e.class} - " + error_message
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
