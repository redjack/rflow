require 'active_record'
require 'rflow/configuration/uuid_keyed'

class RFlow
  class Configuration
    # Represents a component definition in the SQLite database.
    class Component < ConfigurationItem
      include UUIDKeyed
      include ActiveModel::Validations

      # @!attribute options
      #   Open-ended Hash of component options, serialized via YAML to a single column.
      #   @return [Hash]
      serialize :options, Hash

      # @!attribute shard
      #   The {Shard} in which this {Component} is to run.
      #   @return [Shard]
      belongs_to :shard, :primary_key => 'uuid', :foreign_key => 'shard_uuid'

      # @!attribute input_ports
      #   The {InputPort}s of this component.
      #   @return [Array<InputPort>]
      has_many :input_ports,  :primary_key => 'uuid', :foreign_key => 'component_uuid'

      # @!attribute output_ports
      #   The {OutputPort}s of this component.
      #   @return [Array<OutputPort>]
      has_many :output_ports, :primary_key => 'uuid', :foreign_key => 'component_uuid'

      #TODO: Get this to work
      #has_many :input_connections, :through => :input_ports, :source => :input_connections
      #has_many :output_connections, :through => :output_ports, :source => :output_connection

      validates_uniqueness_of :name
    end
  end
end
