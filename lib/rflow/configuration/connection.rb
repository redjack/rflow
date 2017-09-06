require 'active_record'
require 'rflow/configuration/uuid_keyed'

class RFlow
  class Configuration
    # Represents a component-to-component connection in the SQLite database.
    class Connection < ConfigurationItem
      # Exception for when the connection is invalid.
      class ConnectionInvalid < StandardError; end

      include UUIDKeyed
      include ActiveModel::Validations

      # @!attribute options
      #   Open-ended Hash of component options, serialized via YAML to a single column.
      #   @return [Hash]
      serialize :options, Hash

      # @!attribute input_port
      #   The {InputPort} to which this {Connection} delivers messages.
      #   @return [InputPort]
      belongs_to :input_port, :primary_key => 'uuid', :foreign_key => 'input_port_uuid'

      # @!attribute output_port
      #   The {OutputPort} from which this {Connection} receives messages.
      #   @return [OutputPort]
      belongs_to :output_port,:primary_key => 'uuid', :foreign_key => 'output_port_uuid'

      before_create :merge_default_options!

      validates_uniqueness_of :uuid
      validates_presence_of :output_port_uuid, :input_port_uuid

      validate :all_required_options_present?

      # @!visibility private
      def all_required_options_present?
        self.class.required_options.each do |option_name|
          unless self.options.include? option_name.to_s
            errors.add(:options, "must include #{option_name} for #{self.class.to_s}")
          end
        end
      end

      # @!visibility private
      def merge_default_options!
        self.options ||= {}
        self.class.default_options.each do |name, default_value_or_proc|
          self.options[name.to_s] ||= default_value_or_proc.is_a?(Proc) ? default_value_or_proc.call(self) : default_value_or_proc
        end
      end

      # Should return a list of require option names which will be
      # used in validations. To be overridden by subclasses.
      # @return [Array<String>]
      def self.required_options; []; end

      # Should return a hash of default options, where the keys are
      # the option names and the values are either default option
      # values or Procs that take a single connection argument.  This
      # allow defaults to use other parameters in the connection to
      # construct the appropriate default value. To be overridden
      # by subclasses.
      # @return [Hash]
      def self.default_options; {}; end

      # By default, no broker processes are required to manage a connection.
      # To be overridden by subclasses.
      # @return [Array<Broker>]
      def brokers; []; end
    end

    # Subclass of {Connection} for ZMQ connections and their required options.
    class ZMQConnection < Connection
      # Default options required for ZeroMQ connection.
      # @return [Hash]
      def self.default_options
        {
          'output_socket_type'    => 'PUSH',
          'output_address'        => lambda{|conn| "ipc://rflow.#{conn.uuid}"},
          'output_responsibility' => 'connect',
          'input_socket_type'     => 'PULL',
          'input_address'         => lambda{|conn| "ipc://rflow.#{conn.uuid}"},
          'input_responsibility'  => 'bind',
        }
      end
    end

    # Subclass of {Connection} for brokered ZMQ connections and their required options.
    #
    # We name the IPCs to resemble a quasi-component. Outputting to this
    # connection goes to the +in+ of the IPC pair. Reading input from this
    # connection comes from the +out+ of the IPC pair.
    #
    # The broker shuttles messages between the two to support the many-to-many
    # delivery pattern.
    class BrokeredZMQConnection < Connection
      # Default ZeroMQ options required for broker connection.
      def self.default_options
        {
          'output_socket_type'    => 'PUSH',
          'output_address'        => lambda{|conn| "ipc://rflow.#{conn.uuid}.in"},
          'output_responsibility' => 'connect',
          'input_socket_type'     => 'PULL',
          'input_address'         => lambda{|conn| "ipc://rflow.#{conn.uuid}.out"},
          'input_responsibility'  => 'connect',
        }
      end

      # A brokered ZMQ connection requires one broker process.
      # @return [Array<Broker>]
      def brokers
        @brokers ||= [ZMQStreamer.new(self)]
      end
    end

    # Represents the broker process configuration. No special parameters
    # that can't be derived from the connection. Not persisted in the database -
    # it's encapsulated in the nature of the connection.
    class ZMQStreamer
      # Backreference to the {Connection}.
      # @return [Connection]
      attr_reader :connection

      def initialize(connection)
        @connection = connection
      end
    end

    # For testing purposes only.
    # @!visibility private
    class NullConnectionConfiguration
      attr_accessor :name
      attr_accessor :uuid
      attr_accessor :options
      attr_accessor :input_port_key
      attr_accessor :output_port_key
      attr_accessor :delivery
    end
  end
end
