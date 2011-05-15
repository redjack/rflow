require 'rflow/util'
require 'rflow/configuration/setting'
require 'rflow/configuration/component'
require 'rflow/configuration/port'
require 'rflow/configuration/connection'

# Config file requires at the bottom of the file

class RFlow
  class Configuration
    class ConfigurationInvalid < StandardError; end
    
    class << self
#      attr_accessor :config_file

      def available_data_types
        @available_data_types ||= Hash.new {|hash, key| hash[key] = Hash.new}
      end

      def available_data_extensions
        @available_data_extensions ||= Hash.new {|hash, key| hash[key] = Array.new}
      end

      def available_components
        @available_components ||= Hash.new
      end
    end

    
    # TODO: refactor each of these add_available_* into collections to
    # make DRYer.  Also figure out what to do with all to to_syms
    def self.add_available_data_type(data_type_name, data_serialization_type, data_schema)
      unless data_serialization_type == 'avro'
        error_message = "Data serialization_type must be 'avro' for '#{data_type_name}'"
        RFlow.logger.error error_message
        raise ArgumentError, error_message
      end

      if available_data_types[data_type_name.to_s].include? data_serialization_type.to_s
        error_message = "Data type '#{data_type_name}' already defined for serialization_type '#{data_serialization_type}'"
        RFlow.logger.error error_message
        raise ArgumentError, error_message
      end

      available_data_types[data_type_name.to_s][data_serialization_type.to_s] = data_schema
    end

    # The data_extension parameter should be the name of a ruby module
    # that will extend RFlow::Message::Data object to provide
    # additional methods/capability
    def self.add_available_data_extension(data_type_name, data_extension)
      unless data_extension.is_a? Module
        error_message = "Invalid data extension #{data_extension} for #{data_type_name}.  Only Ruby Modules allowed"
        RFlow.logger.error error_message
        raise ArgumentError, error_message
      end

      available_data_extensions[data_type_name] << data_extension
    end

    
    # Used when RFlow::Component is subclassed to add another
    # available component to the list.
    def self.add_available_component(component)
      if available_components.include?(component.name)
        error_message = "Component already '#{component.name}' already defined"
        RFlow.logger.error error_message
        raise ArgumentError, error_message
      end
      available_components[component.name] = component
    end


    def self.establish_config_database_connection(config_database_path)
      RFlow.logger.debug "Establishing connection to config database (#{Dir.getwd}) '#{config_database_path}'"
      ActiveRecord::Base.logger = RFlow.logger
      ActiveRecord::Base.establish_connection(:adapter => "sqlite3",
                                              :database  => config_database_path)
    end

    def self.migrate_database
      RFlow.logger.debug "Applying default migrations to config database"
      migrations_directory_path = File.join(File.dirname(__FILE__), 'configuration', 'migrations')
#      ActiveRecord::Migration.verbose = RFlow.logger
      ActiveRecord::Migrator.migrate migrations_directory_path
    end
    
    def self.initialize_database(config_database_path, config_file_path=nil)
      RFlow.logger.debug "Initializing config database (#{Dir.getwd}) '#{config_database_path}'"
      establish_config_database_connection(config_database_path)
      migrate_database
      
      if config_file_path
        expanded_config_file_path = File.expand_path config_file_path
        working_dir = Dir.getwd
        Dir.chdir File.dirname(config_database_path)

        process_config_file(expanded_config_file_path)

        Dir.chdir working_dir
      end
    end

    
    # Load the config file, which should load/process/store all the
    # elements.  Only run this after the database has been setup
    def self.process_config_file(config_file_path)
      RFlow.logger.info "Processing config file (#{Dir.getwd}) '#{config_file_path}'"
      load config_file_path

      RFlow.logger.debug "Defaulting non-existing config values"
      merge_defaults! 
    end

    def self.merge_defaults!
      Setting::DEFAULTS.each do |name, default_value_or_proc|
        Setting.find_or_create_by_name(:name => name,
                                       :value => default_value_or_proc.is_a?(Proc) ? default_value_or_proc.call() : default_value_or_proc)
      end
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
      self.class.establish_config_database_connection(config_database_path)
      
      RFlow.logger.debug self.to_s
    end

    
    def to_s
      string = "Configuration:\n"
      Setting.all.each do |setting|
        string << "Setting: '#{setting.name}' = '#{setting.value}'\n"
      end
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

    
    def components
      Component.all
    end

    
    def component(component_instance_uuid)
      Component.find_by_uuid component_instance_uuid
    end
    
    
    def settings
      Setting.all
    end

    def available_components
      self.class.available_components
    end
  end
end

# Incorporate various config file processors
require 'rflow/configuration/ruby_dsl'
