require 'rflow/util'

class RFlow

  # Contains all the configuration data and methods for RFlow.
  # Interacts directly with underlying sqlite database, and keeps a
  # registry of available data types, extensions, and components.
  # Also includes an external DSL, RubyDSL, that can be used in
  # crafting config-like files that load the database.
  #
  # Configuration provides a MVC-like framework for config files,
  # where the models are the Setting, Component, Port, and Connection
  # subclasses, the controllers are things like RubyDSL, and the views
  # are defined relative to the controllers
  class Configuration

    # An exception class
    class ConfigurationInvalid < StandardError; end


    # A class to hold DB config and connection information
    class ConfigDB < ActiveRecord::Base
        self.abstract_class = true
    end


    # A collection class for data extensions that supports a naive
    # prefix-based 'inheritance' on lookup.  When looking up a key
    # with [] all existing keys will be examined to determine if the
    # existing key is a string prefix of the lookup key. All the
    # results are consolidated into a single, flattened array.
    class DataExtensionCollection

      def initialize
        # TODO: choose a different data structure ...
        @hash = Hash.new {|hash, key| hash[key] = Array.new}
      end

      # Return an array of all of the values that have keys that are
      # prefixes of the lookup key.
      def [](key)
        key_string = key.to_s
        @hash.map do |data_type, extensions|
          key_string.start_with?(data_type) ? extensions : nil
        end.flatten.compact
      end

      # Adds a data extension for a given data type to the collection
      def add(data_type, extension)
        @hash[data_type.to_s] << extension
      end

      # Remove all elements from the collection.  Useful for testing,
      # not much else
      def clear
        @hash.clear
      end

    end


    class << self

      # A collection of data types (schemas) indexed by their name and
      # their schema type ('avro').
      def available_data_types
        @available_data_types ||= Hash.new {|hash, key| hash[key] = Hash.new}
      end

      # A DataExtensionCollection to hold available extensions that
      # will be applied to the de-serialized data types
      def available_data_extensions
        @available_data_extensions ||= DataExtensionCollection.new
      end

      # A Hash of defined components, usually automatically populated
      # when a component subclasses RFlow::Component
      def available_components
        @available_components ||= Hash.new
      end
    end

    # TODO: refactor each of these add_available_* into collections to
    # make DRYer.  Also figure out what to do with all to to_syms

    # Add a schema to the available_data_types class attribute.
    # Schema is indexed by data_type_name and schema/serialization
    # type.  'avro' is currently the only supported
    # data_serialization_type.
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

    # Add a data extension to the available_data_extensions class
    # attributes.  The data_extension parameter should be the name of
    # a ruby module that will extend RFlow::Message::Data object to
    # provide additional methods/capability.  Naive, prefix-based
    # inheritance is possible, see available_data_extensions or the
    # DataExtensionCollection class
    def self.add_available_data_extension(data_type_name, data_extension)
      unless data_extension.is_a? Module
        error_message = "Invalid data extension #{data_extension} for #{data_type_name}.  Only Ruby Modules allowed"
        RFlow.logger.error error_message
        raise ArgumentError, error_message
      end

      available_data_extensions.add data_type_name, data_extension
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


    # Connect to the configuration sqlite database, but use the
    # ConfigDB subclass to protect the connection information from
    # other ActiveRecord apps (i.e. Rails)
    def self.establish_config_database_connection(config_database_path)
      RFlow.logger.debug "Establishing connection to config database (#{Dir.getwd}) '#{config_database_path}'"
      ActiveRecord::Base.logger = RFlow.logger
      ConfigDB.establish_connection(:adapter => "sqlite3",
                                    :database  => config_database_path)
    end


    # Using default ActiveRecord migrations, attempt to migrate the
    # database to the latest version.
    def self.migrate_database
      RFlow.logger.debug "Applying default migrations to config database"
      migrations_directory_path = File.join(File.dirname(__FILE__), 'configuration', 'migrations')
#      ActiveRecord::Migration.verbose = RFlow.logger
      ActiveRecord::Migrator.migrate migrations_directory_path
    end


    # Load the config file, which should load/process/store all the
    # elements.  Only run this after the database has been setup
    def self.process_config_file(config_file_path)
      RFlow.logger.info "Processing config file (#{Dir.getwd}) '#{config_file_path}'"
      load config_file_path
    end


    # Connect to the configuration database, migrate it to the latest
    # version, and process a config file if provided.
    def self.initialize_database(config_database_path, config_file_path=nil)
      RFlow.logger.debug "Initializing config database (#{Dir.getwd}) '#{config_database_path}'"

      RFlow.logger.debug "Establishing connection to config database (#{Dir.getwd}) '#{config_database_path}'"
      ActiveRecord::Base.logger = RFlow.logger
      ActiveRecord::Base.establish_connection(:adapter => "sqlite3",
                                              :database  => config_database_path)

      migrate_database

      expanded_config_file_path = File.expand_path config_file_path if config_file_path

      working_dir = Dir.getwd
      Dir.chdir File.dirname(config_database_path)

      if config_file_path
        process_config_file(expanded_config_file_path)
      end

      RFlow.logger.debug "Defaulting non-existing config values"
      merge_defaults!

      Dir.chdir working_dir

      self.new(config_database_path)
    end


    # Make sure that the configuration has all the necessary values set.
    def self.merge_defaults!
      Setting::DEFAULTS.each do |name, default_value_or_proc|
        setting = Setting.find_or_create_by_name(:name => name,
                                                 :value => default_value_or_proc.is_a?(Proc) ? default_value_or_proc.call() : default_value_or_proc)
        unless setting.valid?
          error_message = setting.errors.map do |attribute, error_string|
            error_string
          end.join ', '
          raise RuntimeError, error_message
        end
      end
    end


    attr_accessor :config_database_path
    attr_accessor :cached_settings
    attr_accessor :cached_components
    attr_accessor :cached_ports
    attr_accessor :cached_connections


    def initialize(config_database_path=nil)
      @cached_settings = Hash.new
      @cached_components = Hash.new
      @cached_ports = []
      @cached_connections = []

      # If there is not a config DB path, assume that an AR
      # conncection has already been established
      if config_database_path
        @config_database_path = config_database_path
        self.class.establish_config_database_connection(config_database_path)
      end

      # Validate the connected database.  TODO: make this more
      # complete, i.e. validate the various columns
      begin
        Setting.first
        Component.first
        Port.first
        Connection.first
      rescue ActiveRecord::StatementInvalid => e
        error_message = "Invalid schema in configuration database: #{e.message}"
        RFlow.logger.error error_message
        raise ArgumentError, error_message
      end
    end


    def to_s
      string = "Configuration:\n"

      settings.each do |setting|
        string << "Setting: '#{setting.name}' = '#{setting.value}'\n"
      end

      shards.each do |shard|
        string << "Shard #{shard.name} (#{shard.uuid}), type #{shard.class.name}, count #{shard.count}\n"
        shard.components.each do |component|
          string << "  Component '#{component.name}' as #{component.specification} (#{component.uuid})\n"
          component.output_ports.each do |output_port|
            output_port.output_connections.each do |output_connection|
              input_port = output_connection.input_port
              string << "    OutputPort '#{output_port.name}' key '#{output_connection.output_port_key}' (#{output_port.uuid}) =>\n"
              string << "      Connection '#{output_connection.name}' as #{output_connection.type} (#{output_connection.uuid}) =>\n"
              string << "      InputPort '#{input_port.name}' key '#{output_connection.input_port_key}' (#{input_port.uuid}) Component '#{input_port.component.name}' (#{input_port.component.uuid})\n"
            end
          end
        end
      end
      string
    end

    # Helper method to access settings with minimal syntax
    def [](setting_name)
      Setting.find_by_name(setting_name).value rescue nil
    end

    def settings
      Setting.all
    end

    def shards
      Shard.all
    end

    def shard(shard_instance_uuid)
      Shard.find_by_uuid shard_instance_uuid
    end

    def components
      Component.all
    end

    def component(component_instance_uuid)
      Component.find_by_uuid component_instance_uuid
    end

    def available_components
      self.class.available_components
    end
  end
end

# Load the models
require 'rflow/configuration/setting'
require 'rflow/configuration/shard'
require 'rflow/configuration/component'
require 'rflow/configuration/port'
require 'rflow/configuration/connection'

# Incorporate various config file processors
require 'rflow/configuration/ruby_dsl'
