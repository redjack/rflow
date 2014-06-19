require 'active_record'
require 'rflow/configuration/uuid_keyed'

class RFlow
  class Configuration
    class Connection < ConfigurationItem
      class ConnectionInvalid < StandardError; end

      include UUIDKeyed
      include ActiveModel::Validations

      serialize :options, Hash

      belongs_to :input_port, :primary_key => 'uuid', :foreign_key => 'input_port_uuid'
      belongs_to :output_port,:primary_key => 'uuid', :foreign_key => 'output_port_uuid'

      before_create :merge_default_options!

      validates_uniqueness_of :uuid
      validates_presence_of :output_port_uuid, :input_port_uuid

      validate :all_required_options_present?

      def all_required_options_present?
        self.class.required_options.each do |option_name|
          unless self.options.include? option_name.to_s
            errors.add(:options, "must include #{option_name} for #{self.class.to_s}")
          end
        end
      end

      def merge_default_options!
        self.options ||= {}
        self.class.default_options.each do |name, default_value_or_proc|
          self.options[name.to_s] ||= default_value_or_proc.is_a?(Proc) ? default_value_or_proc.call(self) : default_value_or_proc
        end
      end

      # Should return a list of require option names which will be
      # used in validations.  To be overridden.
      def self.required_options; []; end

      # Should return a hash of default options, where the keys are
      # the option names and the values are either default option
      # values or Procs that take a single connection argument.  This
      # allow defaults to use other parameters in the connection to
      # construct the appropriate default value.
      def self.default_options; {}; end

      # By default, no broker processes are required to manage a connection.
      def brokers; []; end
    end

    # STI Subclass for ZMQ connections and their required options
    class ZMQConnection < Connection
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

    # STI Subclass for brokered ZMQ connections and their required options
    #
    # We name the IPCs to resemble a quasi-component. Outputting to this
    # connection goes to the 'in' of the IPC pair. Reading input from this
    # connection comes from the 'out' of the IPC pair.
    #
    # The broker shuttles messages between the two to support the many-to-many
    # delivery pattern.
    class BrokeredZMQConnection < Connection
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
      def brokers
        @brokers ||= [ZMQStreamer.new(self)]
      end
    end

    # Represents the broker process configuration. No special parameters
    # that can't be derived from the connection. Not persisted in the database -
    # it's encapsulated in the nature of the connection.
    class ZMQStreamer
      attr_reader :connection

      def initialize(connection)
        @connection = connection
      end
    end

    # for testing purposes
    class NullConfiguration
      attr_accessor :name, :uuid, :options, :input_port_key, :output_port_key, :delivery
    end
  end
end
