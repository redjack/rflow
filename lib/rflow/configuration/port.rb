require 'active_record'
require 'rflow/configuration/uuid_keyed'

class RFlow
  class Configuration
    # Represents a component port in the SQLite database.
    class Port < ConfigurationItem
      include UUIDKeyed
      include ActiveModel::Validations

      # @!attribute component
      #   The {Component} to which this port belongs.
      #   @return [Component]
      belongs_to :component,  :primary_key => 'uuid', :foreign_key => 'component_uuid'

      # TODO: Make some sort of component/port validation work here
      #validate :component_has_defined_port
    end

    # Subclass of {Port} to represent input ports.
    class InputPort < Port
      # @!attribute input_connections
      #   The connections delivering messages to this {InputPort}.
      #   @return [Array<Connection>]
      has_many :input_connections, :class_name => 'RFlow::Configuration::Connection', :primary_key => 'uuid', :foreign_key => 'input_port_uuid'

      # @!attribute connections
      #   Synonym for {input_connections}.
      #   @return [Array<Connection>]
      has_many :connections, :class_name => 'RFlow::Configuration::Connection', :primary_key => 'uuid', :foreign_key => 'input_port_uuid'
    end

    # Subclass of {Port} to represent output ports.
    class OutputPort < Port
      # @!attribute output_connections
      #   The connections receiving messages from this {OutputPort}.
      #   @return [Array<Connection>]
      has_many :output_connections, :class_name => 'RFlow::Configuration::Connection', :primary_key => 'uuid', :foreign_key => 'output_port_uuid'

      # @!attribute connections
      #   Synonym for {output_connections}.
      #   @return [Array<Connection>]
      has_many :connections, :class_name => 'RFlow::Configuration::Connection', :primary_key => 'uuid', :foreign_key => 'output_port_uuid'
    end
  end
end
