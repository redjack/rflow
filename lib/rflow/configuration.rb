class RFlow
  # Contains all the configuration data and methods for RFlow.
  # Interacts directly with underlying SQLite database, and keeps a
  # registry of available data types, extensions, and components.
  # Also includes an external DSL, RubyDSL, that can be used in
  # crafting config-like files that load the database.
  #
  # {Configuration} provides a MVC-like framework for config files,
  # where the models are the {Setting}, {Component}, {Port}, and {Connection}
  # subclasses, the controllers are things like RubyDSL, and the views
  # are defined relative to the controllers.
  class Configuration
    # A collection class for data extensions that supports a naive
    # prefix-based 'inheritance' on lookup.  When looking up a key
    # with {[]} all existing keys will be examined to determine if the
    # existing key is a string prefix of the lookup key. All the
    # results are consolidated into a single, flattened array.
    class DataExtensionCollection
      def initialize
        # TODO: choose a different data structure ...
        @extensions_for = Hash.new {|hash, key| hash[key] = []}
      end

      # Return an array of all of the values that have keys that are
      # prefixes of the lookup key.
      # @return [Array]
      def [](key)
        @extensions_for.
          find_all {|data_type, _| key.to_s.start_with?(data_type) }.
          flat_map {|_, extensions| extensions }
      end

      # Adds a data extension for a given data type to the collection
      # @return [void]
      def add(data_type, extension)
        @extensions_for[data_type.to_s] << extension
      end

      # Remove all elements from the collection.  Useful for testing,
      # not much else
      # @return [void]
      def clear
        @extensions_for.clear
      end
    end

    # Base class for persisted RFlow configuration items.
    class ConfigurationItem < ActiveRecord::Base
      self.abstract_class = true
    end

    class << self
      # A collection of data types (schemas) indexed by their name and
      # their schema type ('avro').
      # @return [Hash]
      def available_data_types
        @available_data_types ||= Hash.new {|hash, key| hash[key] = {}}
      end

      # A {DataExtensionCollection} to hold available extensions that
      # will be applied to the de-serialized data types.
      # @return [DataExtensionCollection]
      def available_data_extensions
        @available_data_extensions ||= DataExtensionCollection.new
      end

      # A Hash of defined components, usually automatically populated
      # when a component subclasses {RFlow::Component}.
      # @return [Hash]
      def available_components
        @available_components ||= {}
      end

      # Add a schema to the {available_data_types} class attribute.
      # Schema is indexed by +name+ and +serialization_type+.
      # +avro+ is currently the only supported +serialization_type+.
      # @return [void]
      def add_available_data_type(name, serialization_type, schema)
        # TODO: refactor each of these add_available_* into collections to
        # make DRYer.  Also figure out what to do with all to to_syms
        raise ArgumentError, "Data serialization_type must be 'avro' for '#{name}'" unless serialization_type == 'avro'

        if available_data_types[name.to_s].include? serialization_type.to_s
          raise ArgumentError, "Data type '#{name}' already defined for serialization_type '#{serialization_type}'"
        end

        available_data_types[name.to_s][serialization_type.to_s] = schema
      end

      # Add a data extension to the {available_data_extensions} class
      # attribute. The +extension+ parameter should be the name of
      # a ruby module that will extend {RFlow::Message::Data} to
      # provide additional methods/capability. Naive, prefix-based
      # inheritance is possible, see {available_data_extensions} or
      # {DataExtensionCollection}.
      # @return [void]
      def add_available_data_extension(data_type_name, extension)
        unless extension.is_a? Module
          raise ArgumentError, "Invalid data extension #{extension} for #{data_type_name}.  Only Ruby Modules allowed"
        end

        available_data_extensions.add data_type_name, extension
      end

      # Used when {RFlow::Component} is subclassed to add another
      # available component to the list.
      # @return [void]
      def add_available_component(component)
        if available_components.include?(component.name)
          raise ArgumentError, "Component already '#{component.name}' already defined"
        end
        available_components[component.name] = component
      end

      # Connect to the configuration SQLite database, but use
      # {ConfigurationItem} to protect the connection information from
      # other ActiveRecord apps (i.e. Rails).
      # @return [void]
      def establish_config_database_connection(database_path)
        RFlow.logger.debug "Establishing connection to config database (#{Dir.getwd}) '#{database_path}'"
        ActiveRecord::Base.logger = RFlow.logger
        ConfigurationItem.establish_connection(:adapter => 'sqlite3', :database => database_path)
      end

      # Using default ActiveRecord migrations, attempt to migrate the
      # database to the latest version.
      # @return [void]
      def migrate_database
        RFlow.logger.debug 'Applying default migrations to config database'
        migrations_path = File.join(File.dirname(__FILE__), 'configuration', 'migrations')
        ActiveRecord::Migration.verbose = false
        ActiveRecord::Migrator.migrate migrations_path
      end

      # Load the config file, which should load/process/store all the
      # elements. Only run this after the database has been setup
      # @return [void]
      def process_config_file(path)
        RFlow.logger.info "Processing config file (#{Dir.getwd}) '#{path}'"
        load path
      end

      # Connect to the configuration database, migrate it to the latest
      # version, and process a config file if provided.
      # @return [void]
      def initialize_database(database_path, config_file_path = nil)
        RFlow.logger.debug "Initializing config database (#{Dir.getwd}) '#{database_path}'"

        # TODO should not need this line
        ActiveRecord::Base.establish_connection(:adapter => 'sqlite3', :database => database_path)

        establish_config_database_connection database_path
        migrate_database

        working_dir = Dir.getwd
        Dir.chdir File.dirname(database_path)

        if config_file_path
          process_config_file File.expand_path(config_file_path)
        end

        RFlow.logger.debug 'Defaulting non-existing config values'
        merge_defaults!

        Dir.chdir working_dir

        self.new(database_path)
      end

      # Make sure that the configuration has all the necessary values set.
      # @return [void]
      def merge_defaults!
        Setting::DEFAULTS.each do |name, default_value_or_proc|
          value = default_value_or_proc.is_a?(Proc) ? default_value_or_proc.call() : default_value_or_proc
          setting = Setting.find_or_create_by(:name => name, :value => value)
          unless setting.valid?
            raise RuntimeError, setting.errors.map {|_, msg| msg }.join(', ')
          end
        end
      end
    end

    def initialize(database_path = nil)
      # If there is not a config DB path, assume that an AR
      # connection has already been established
      if database_path
        @database_path = database_path
        Configuration.establish_config_database_connection(database_path)
      end

      # Validate the connected database.
      # TODO: make this more complete, i.e. validate the various columns
      begin
        [Setting, Shard, Component, Port, Connection].each(&:first)
      rescue ActiveRecord::StatementInvalid => e
        raise ArgumentError, "Invalid schema in configuration database: #{e.message}"
      end
    end

    # Output the RFlow configuration to a pretty-printed String.
    # @return [String]
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

    # Retrieve a setting value by name from the SQLite database.
    # @return [Object]
    def [](name); Setting.find_by_name(name).value rescue nil; end

    # Retrieve all the {Setting}s from the SQLite database.
    # @return [Array<Setting>]
    def settings; Setting.all; end

    # Retrieve all the {Shard}s from the SQLite database.
    # @return [Array<Shard>]
    def shards; Shard.all; end

    # Retrieve all the {Connection}s from the SQLite database.
    # @return [Array<Connection>]
    def connections; Connection.all; end

    # Retrieve a single {Shard} by UUID from the SQLite database.
    # @return [Shard]
    def shard(uuid); Shard.find_by_uuid uuid; end

    # Retrieve all the {Component}s from the SQLite database.
    # @return [Array<Component>]
    def components; Component.all; end

    # Retrieve a single {Component} by UUID from the SQLite database.
    # @return [Shard]
    def component(uuid); Component.find_by_uuid uuid; end

    # Retrieve the mapping from component name to {Component}.
    # @return [Hash]
    def available_components; Configuration.available_components; end
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
