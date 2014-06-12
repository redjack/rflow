require 'rflow/configuration'

class RFlow
  class Configuration
    # Ruby DSL config file controller.
    # TODO: more docs and examples
    class RubyDSL
      private
      attr_accessor :setting_specs, :shard_specs, :connection_specs, :default_shard

      public
      def initialize
        @default_shard = {:name => "DEFAULT", :type => :process, :count => 1, :components => []}
        @current_shard = default_shard

        @setting_specs = []
        @shard_specs = [default_shard]
        @connection_specs = []
      end

      # DSL method to specify a name/value pair.  RFlow core uses the
      # 'rflow.' prefix on all of its settings.  Custom settings
      # should use a custom (unique) prefix
      def setting(name, value)
        setting_specs << {:name => name.to_s, :value => value.to_s, :config_line => get_config_line(caller)}
      end

      # DSL method to specify a shard block for either a process or thread
      def shard(name, options = {})
        raise ArgumentError, "Cannot use DEFAULT as a shard name" if name == 'DEFAULT'
        raise ArgumentError, "Cannot nest shards" if @current_shard != default_shard

        type = if options[:thread] || options[:type] == :thread; :thread
               else :process
               end

        count = options[type] || options[:count] || 1

        @current_shard = {:name => name, :type => type, :count => count, :components => [], :config_line => get_config_line(caller)}
        shard_specs << @current_shard
        yield self
        @current_shard = default_shard
      end

      # DSL method to specify a component.  Expects a name,
      # specification, and set of component specific options, that
      # must be marshallable into the database (i.e. should all be strings)
      def component(name, specification, options = {})
        @current_shard[:components] << {
          :name => name,
          :specification => specification.to_s, :options => options,
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
      def connect(hash)
        hash.each do |output_string, input_string|
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
            :config_line => get_config_line(caller)
          }
        end
      end

      # Method called within the config file itself
      def self.configure
        config_file = self.new
        yield config_file
        config_file.process
      end

      # Method to process the 'DSL' objects into the config database
      # via ActiveRecord
      def process
        process_setting_specs
        process_shard_specs
        process_connection_specs
      end

      private
      # Helper function to extract the line of the config that
      # specified the operation.  Useful in printing helpful error messages
      def get_config_line(call_history)
        call_history.first.split(':in').first
      end

      # Splits the connection string into component/port parts
      COMPONENT_PORT_STRING_REGEX = /^(\w+)#(\w+)(?:\[([^\]]+)\])?$/

      def parse_connection_string(string)
        matched = COMPONENT_PORT_STRING_REGEX.match(string)
        raise ArgumentError, "Invalid component/port string specification: #{string}" unless matched
        component_name, port_name, port_key = matched.captures
        [component_name, port_name, port_key]
      end

      # Iterates through each setting specified in the DSL and
      # creates rows in the database corresponding to the setting
      def process_setting_specs
        setting_specs.each do |spec|
          RFlow.logger.debug "Found config file setting '#{spec[:name]}' = (#{Dir.getwd}) '#{spec[:value]}'"
          RFlow::Configuration::Setting.create! :name => spec[:name], :value => spec[:value]
        end
      end

      # Iterates through each shard specified in the DSL and creates
      # rows in the database corresponding to the shard and included
      # components
      def process_shard_specs
        shard_specs.each do |spec|
          RFlow.logger.debug "Found #{spec[:type]} shard '#{spec[:name]}', creating"

          if spec[:components].empty?
            RFlow.logger.warn "Skipping shard '#{spec[:name]}' because it has no components"
            next
          end

          clazz = case spec[:type]
                  when :process; RFlow::Configuration::ProcessShard
                  when :thread; RFlow::Configuration::ThreadShard
                  else raise RFlow::Configuration::Shard::ShardInvalid, "Invalid shard: #{spec.inspect}"
                  end

          shard = clazz.create! :name => spec[:name], :count => spec[:count]

          spec[:components].each do |component_spec|
            RFlow.logger.debug "Shard '#{spec[:name]}' found component '#{component_spec[:name]}', creating"
            RFlow::Configuration::Component.create!(:shard => shard,
                                                    :name => component_spec[:name],
                                                    :specification => component_spec[:specification],
                                                    :options => component_spec[:options])
          end
        end
      end

      # For each given connection, break up each input/output
      # component/port specification, ensure that the component
      # already exists in the database (by name). Chooses the best
      # connection type for any pair of components.
      def process_connection_specs
        connection_specs.each do |spec|
          begin
            RFlow.logger.debug "Found connection from '#{spec[:output_string]}' to '#{spec[:input_string]}', creating"

            # an input port can be associated with multiple outputs, but
            # an output port can only be associated with one input
            output_component = RFlow::Configuration::Component.find_by_name spec[:output_component_name]
            raise RFlow::Configuration::Connection::ConnectionInvalid,
              "Component '#{spec[:output_component_name]}' not found at #{spec[:config_line]}" unless output_component
            output_port = output_component.output_ports.find_or_initialize_by_name :name => spec[:output_port_name]
            output_port.save!

            input_component = RFlow::Configuration::Component.find_by_name spec[:input_component_name]
            raise RFlow::Configuration::Connection::ConnectionInvalid,
              "Component '#{spec[:input_component_name]}' not found at #{spec[:config_line]}" unless input_component
            input_port = input_component.input_ports.find_or_initialize_by_name :name => spec[:input_port_name]
            input_port.save!

            output_shards = output_component.shard.count
            input_shards = input_component.shard.count

            in_shard_connection = output_component.shard == input_component.shard
            one_to_one = output_shards == 1 && input_shards == 1
            one_to_many = output_shards == 1 && input_shards > 1
            many_to_one = output_shards > 1 && input_shards == 1
            many_to_many = output_shards > 1 && input_shards > 1

            connection_type = many_to_many ? RFlow::Configuration::BrokeredZMQConnection : RFlow::Configuration::ZMQConnection

            conn = connection_type.create!(:name => spec[:name],
                                           :output_port_key => spec[:output_port_key],
                                           :input_port_key => spec[:input_port_key],
                                           :output_port => output_port,
                                           :input_port => input_port)

            # bind on the cardinality-1 side, connect on the cardinality-n side
            if in_shard_connection
              conn.options['output_responsibility'] = 'connect'
              conn.options['input_responsibility'] = 'bind'
              conn.options['output_address'] = "inproc://rflow.#{conn.uuid}"
              conn.options['input_address'] = "inproc://rflow.#{conn.uuid}"
            elsif many_to_one
              conn.options['output_responsibility'] = 'connect'
              conn.options['input_responsibility'] = 'bind'
            elsif one_to_many
              conn.options['output_responsibility'] = 'bind'
              conn.options['input_responsibility'] = 'connect'
            end

            conn.save!
            conn
          rescue Exception => e
            # TODO: Figure out why an ArgumentError doesn't put the
            # offending message into e.message, even though it is printed
            # out if not caught
            raise RFlow::Configuration::Connection::ConnectionInvalid, "#{e.class}: #{e.message} at config '#{spec[:config_line]}'"
          end
        end
      end
    end
  end
end
