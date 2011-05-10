require 'rflow/util'
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

      # Default/Clean-up the database configuration
      RFlow.logger.debug "Defaulting non-existing config values"
      merge_defaults! 

      RFlow.logger.info self.to_s
    end

    
    def to_s
      string = "Configuration:\n"
      Component.all.each do |component|
        string << "Component '#{component.name}' as #{component.specification} (#{component.uuid})\n"
        component.output_ports.each do |output_port|
          output_port.output_connections.each do |output_connection|
            input_port = output_connection.input_port
            string << "\tOutputPort '#{output_port.name}' key '#{output_connection.output_port_key}' (#{output_port.uuid}) =>\n"
            string << "\t\tConnection '#{output_connection.name}' as #{output_connection.type} (#{output_connection.uuid}) =>\n"
            string << "\t\tInputPort '#{input_port.name}' key '#{output_connection.input_port_key}' (#{input_port.uuid}) Component '#{input_port.component.name}' (#{input_port.component.uuid})\n"
          end
        end
      end
      string
    end
      
    # Helper method to access settings with minimal syntax
    def [](setting_name)
      Setting.find_by_name(setting_name).value rescue nil
    end

    
    def merge_defaults!
      # Set the defaults
      Setting::DEFAULTS.each do |name, default_value_or_proc|
        Setting.find_or_create_by_name(:name => name,
                                       :value => default_value_or_proc.is_a?(Proc) ? default_value_or_proc.call(self) : default_value_or_proc)
      end
      # Do anything else necessary to clean-up/expand config
    end


    def components
      Component.all
    end

    
    def component(component_instance_uuid)
      Component.find_by_uuid component_instance_uuid
    end
    
    
    def settings
      Setting.all
    end
  end
end

# Incorporate various config file processors
require 'rflow/configuration/ruby_dsl'
