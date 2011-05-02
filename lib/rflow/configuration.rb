require 'uuidtools'

require 'rflow/configuration/setting'
require 'rflow/configuration/component'
require 'rflow/configuration/port'
require 'rflow/configuration/connection'

# Config file requires at the bottom of the file

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

#      # Load any stored config into memory
#      RFlow.logger.debug "Loading config database (#{Dir.getwd}) '#{self.config_database_path}'"
#      reload!

      # Default/Clean-up the database configuration
      RFlow.logger.debug "Defaulting non-existing config values"
      default! 

      #      # Perform some validations of the config
#      RFlow.logger.debug "Validating config"
#      validate! 
#      # Store the in-memory configuration to the database
#      RFlow.logger.debug "Storing config"
#      store!
#      # Reload the configuration from the database
#      RFlow.logger.debug "Reloading config"
#      reload!

      RFlow.logger.info "Configuration:\n#{self.to_s}"
    end

    def to_s
      string = "Configuration:\n"
      Component.all.each do |component|
        string << "Component '#{component.name}' (#{component.uuid}) "
        component.output_ports.each do |output_port|
          input_port = output_port.outgoing_connection.input_port
          string << "OutputPort '#{output_port.name}' (#{output_port.uuid}) =>\n"
          string << "\tConnection '#{output_port.outgoing_connection.name}' (#{output_port.outgoing_connection.uuid}) =>\n"
          string << "\tInputPort '#{input_port.name}' (#{input_port.uuid}) Component '#{input_port.component.name}' (#{input_port.component.uuid})\n"
        end
      end
      string
    end
    
    def parse_connection_string(connection_string)
      connection_string.split '#'
    end
    
    # Helper method to access settings
    def [](setting_name)
      Setting.find_by_name(setting_name).value rescue nil
    end

    
    def default!(relative_directory='.')
      # Set the defaults
      Setting::DEFAULTS.each do |name, default_value_proc|
        Setting.find_or_create_by_name :name => name, :value => default_value_proc.call(self)
      end

      # Do anything else necessary to clean-up/expand config
    end


    # Probably need these later, but not now
#    def validate!
#      # Run the standard ActiveRecord validations
#      cached_settings.each do |name, model|
#        unless model.valid?
#          error_message = "Invalid setting '#{name}' = (#{Dir.getwd}) '#{model.value}': #{model.errors.inspect}"
#          RFlow.logger.error error_message
#          raise Setting::SettingInvalid, error_message
#        end
#      end
#    end
#
#    
#    def store!
#      [cached_settings.values, cached_components, cached_ports, cached_connections].each do |collection|
#        collection.each do |model|
#          model.save
#        end
#      end
#    end
#
#    
#    def reload!
#      # TODO: Look at this for correctness
#      cached_settings.clear
#      Setting.all.each do |setting_model|
#        RFlow.logger.debug "Loading '#{setting_model.name}' = (#{Dir.getwd}) '#{setting_model.value}'"
#        cached_settings[setting_model.name] = setting_model
#      end
#
#      # TODO: Load other configs
#    end

    def components
      Component.all
    end

    def settings
      Setting.all
    end
  end
end

# Incorporate various config file processors
require 'rflow/configuration/ruby_dsl'
