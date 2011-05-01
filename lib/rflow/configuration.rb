require 'uuidtools'

require 'rflow/configuration/setting'
require 'rflow/configuration/component'
require 'rflow/configuration/port'
require 'rflow/configuration/connection'

class RFlow
  class Configuration
    class << self
      attr_accessor :config_file

      attr_accessor :available_data_schemas
      attr_accessor :available_data_extensions
      attr_accessor :available_components
    end

    
    # TODO: refactor each of these add_available_* into collections to
    # make DRYer
    def self.add_available_data_schema(data_schema)
      self.available_data_schemas ||= Hash.new
      if self.available_data_schemas.include?(data_schema.name)
        error_message = "Data schema '#{data_schema.name}' already defined"
        RFlow.logger.error error_message
        raise ArgumentError, error_message
      end
      self.available_data_schemas[data_schema.name] = data_schema
    end

    
    def self.add_available_data_extension(data_extension)
      self.available_data_extensions ||= Hash.new
      if self.available_data_extensions.include?(data_extension.name)
        error_message = "Data extension '#{data_extension.name}' already defined"
        RFlow.logger.error error_message
        raise ArgumentError, error_message
      end
      self.available_data_extensions[data_extension.name] = data_extension
    end

    
    def self.add_available_component(component)
      self.available_components ||= Hash.new
      if self.available_components.include?(component.name)
        error_message = "Component already '#{component.name}' already defined"
        RFlow.logger.error error_message
        raise ArgumentError, error_message
      end
      self.available_components[component.name] = component
    end

    
    def self.initialize_database(config_database_path, config_file_path=nil)
      Dir.chdir File.dirname(config_database_path)

      ActiveRecord::Base.logger = RFlow.logger
      ActiveRecord::Base.establish_connection(:adapter => "sqlite3",
                                              :database  => config_database_path)
      migrations_directory_path = File.join(File.dirname(__FILE__), 'configuration', 'migrations')

      RFlow.logger.info "Applying default migrations to config database (#{Dir.getwd}) #{config_database_path}"
      ActiveRecord::Migrator.migrate migrations_directory_path

      if config_file_path
        process_config_file(config_file_path)
      end
    end

    
    # Load the config file, which should load/process/store all the
    # elements.  Only run this after the database has been setup
    def self.process_config_file(config_file_path)
      RFlow.logger.debug "Processing config file (#{Dir.getwd}) '#{config_file_path}'"
      load config_file_path
    end

    
    attr_accessor :config_database_path
    attr_accessor :cached_settings
    attr_accessor :cached_components
    attr_accessor :cached_ports
    attr_accessor :cached_connections

    
    def initialize(config_database_path)
      @cached_settings = Hash.new
      @cached_components = Hash.new
      @cached_ports = []
      @cached_connections = []

      @config_database_path = config_database_path
      self.class.initialize_database(@config_database_path)


      # TODO: Take out all the 'self's possible

      # Load any stored config into memory
      RFlow.logger.debug "Loading config database (#{Dir.getwd}) '#{self.config_database_path}'"
      reload!
      # Clean-up the in-memory configuration
      RFlow.logger.debug "Defaulting non-existing config values"
      default! 
      # Perform some validations of the config
      RFlow.logger.debug "Validating config"
      validate! 
      # Store the in-memory configuration to the database
      RFlow.logger.debug "Storing config"
      store!
      # Reload the configuration from the database
      RFlow.logger.debug "Reloading config"
      reload!

      RFlow.logger.info "Configuration:"
      Component.all.each do |component|
        RFlow.logger.info "Component '#{component.name}' (#{component.uuid})"
        component.output_ports.each do |output_port|
          input_port = output_port.outgoing_connection.input_port
          RFlow.logger.info"\tOutputPort '#{output_port.name}' (#{output_port.uuid}) => Connection '#{output_port.outgoing_connection.name}' (#{output_port.outgoing_connection.uuid}) => InputPort '#{input_port.name}' (#{input_port.uuid})"
        RFlow.logger.info "Component '#{component.name}' (#{component.uuid})"
          RFlow.logger.info "\t\tComponent '#{input_port.component.name}' (#{input_port.component.uuid})"
        end
      end
      
      
      self
    end

    def parse_connection_string(connection_string)
      connection_string.split '#'
    end
    
    # Helper method to access settings
    def [](setting_name)
      cached_settings[setting_name].value if cached_settings.include?(setting_name)
    end

#     # Helper method to set settings
#     def []=(setting_name, setting_value)
#       add_setting Setting.new(:name => setting_name, :value => setting_value)
#     end
# 
#     # TODO: put this directly on the cached_settings hash to make it
#     #       more Rubyriffic
#     def add_setting(setting)
#       RFlow.logger.debug "Setting '#{setting.name}' = (#{Dir.getwd}) '#{setting.value}'"
#       if cached_settings.include?(setting.name)
#         RFlow.logger.debug "Changing setting '#{setting.name}' from '#{cached_settings[setting.name].value}' to '#{setting.value}'"
#         cached_settings[setting.name].value = setting.value
#       else
#         cached_settings[setting.name] = setting
#       end
#       setting
#     end
#     
#     # TODO: put this directly on the cached_components hash to make it
#     #       more Rubyriffic
#     def add_component(component)
#       RFlow.logger.debug "Component '#{component.name}'"
#       if cached_components.include? component.name
#         error_message = "Duplicate components named #{component.name}"
#         RFlow.logger.error error_message
#         raise ArgumentError, error_message
#       end
#       cached_components[component.name] = component
#       component
#     end

    
    
    def default!(relative_directory='.')
      # Set the defaults
      Setting::DEFAULTS.each do |name, default_value_proc|
        cached_settings[name] ||= Setting.new :name => name, :value => default_value_proc.call(self)
      end

      # Do anything else necessary to clean-up/expand config
    end

    def validate!
      # Run the standard ActiveRecord validations
      cached_settings.each do |name, model|
        unless model.valid?
          error_message = "Invalid setting '#{name}' = (#{Dir.getwd}) '#{model.value}': #{model.errors.inspect}"
          RFlow.logger.error error_message
          raise Setting::SettingInvalid, error_message
        end
      end
    end
    
    def store!
      [cached_settings.values, cached_components, cached_ports, cached_connections].each do |collection|
        collection.each do |model|
          model.save
        end
      end
    end

    def reload!
      # TODO: Look at this for correctness
      cached_settings.clear
      Setting.all.each do |setting_model|
        RFlow.logger.debug "Loading '#{setting_model.name}' = (#{Dir.getwd}) '#{setting_model.value}'"
        cached_settings[setting_model.name] = setting_model
      end

      # TODO: Load other configs
    end

    # Ruby DSL config file controller
    # TODO: better error handling and definition of config file only
    # method, as it won't persist to the DB without a later call to
    # store!
    # TODO: Figure out how to error on redefinition of schemas
    # TODO: Clean up validations so that this class does structure validations
    class RubyDSL

      def self.configure
        config_file = self.new
        yield config_file
        config_file.process
      end
      
      attr_accessor :settings, :components, :connections

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


      def get_config_line(call_history)
        call_history.first.split(':in').first
      end
      

      def setting(setting_name, setting_value)
        settings << {:name => setting_name, :value => setting_value, :config_line => get_config_line(caller)}
      end

      
      def component(component_name, component_specification, component_options={})
        components << {:uuid => generate_uuid_string(component_name), :name => component_name, :specification => component_specification.to_s, :options => component_options, :config_line => get_config_line(caller)}
      end

      
      def connect(connection_hash)
        config_file_line = get_config_line(caller)
        connection_hash.each do |output_string, input_string|
          output_component_name, output_port_name = parse_connection_string(output_string)
          input_component_name, input_port_name = parse_connection_string(input_string)

          # TODO: Validation of input parameters for structure

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

      
      def parse_connection_string(connection_string)
        connection_string.split '#'
      end

      
      def process
        settings.each do |setting|
          RFlow.logger.debug "Found config file setting '#{setting[:name]}' = (#{Dir.getwd}) '#{setting[:value]}'"
          RFlow::Configuration::Setting.create :name => setting[:name], :value => setting[:value]
        end
        
        components.each do |component|
          RFlow.logger.debug "Found component '#{component[:name]}', creating"
          p component
          RFlow::Configuration::Component.create :uuid => component[:uuid], :name => component[:name], :specification => component[:specification], :options => component[:options]
        end

        connections.each do |connection|
          RFlow.logger.debug "Found connection from '#{connection[:output_string]}' to '#{connection[:input_string]}', creating"

          
          # an input port can be associated with multiple outputs, but
          # an output port can only be associated with one input
          begin
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

            connection = RFlow::Configuration::Connection.new :uuid => connection[:uuid], :name => connection[:name]
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
        end
      end
    
    end
  end
end
