require 'active_record'
require 'rflow/configuration/uuid_keyed'

class RFlow
  class Configuration
    class Connection < ActiveRecord::Base
      class ConnectionInvalid < StandardError; end

      include UUIDKeyed
      include ActiveModel::Validations

      serialize :options, Hash
      
      belongs_to :input_port, :primary_key => 'uuid', :foreign_key => 'input_port_uuid'
      belongs_to :output_port,:primary_key => 'uuid', :foreign_key => 'output_port_uuid'

      after_initialize :merge_default_options!
      
      validates_uniqueness_of :uuid
      validates_presence_of :output_port_uuid, :input_port_uuid

      validate :all_required_options_present

      def all_required_options_present
        self.class.required_options.each do |option_name|
          unless options.include? option_name.to_sym
            errors.add(:options, "must include #{option_name}")
          end
        end
      end
      
      def merge_default_options!
        self.class.default_options.each do |option_name, default_value_or_proc|
          self.options[option_name.to_sym] ||= default_value_or_proc.is_a?(Proc) ? default_value_or_proc.call(self) : default_value_or_proc
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

    end

    
    # STI Subclass for ZMQ connections and their required options
    class ZMQConnection < Connection
      def self.required_options
        [:output_socket_type, :output_endpoint, :output_responsibility,
         :input_socket_type, :input_endpoint, :input_responsibility]
      end

      def self.default_options
        {
          :output_socket_type    => :push,
          :output_endpoint       => lambda{|conn| "ipc://rflow.#{conn.uuid}"},
          :output_responsibility => :bind,
          :input_socket_type     => :pull,
          :input_endpoint        => lambda{|conn| "ipc://rflow.#{conn.uuid}"},
          :input_responsibility  => :connect,
        }
      end
      
    end

    
    # STI Subclass for AMQP connections and their required options
    class AMQPConnection < Connection
      def self.required_options
        [:host, :port, :insist, :vhost, :username, :password,
         :routing_key, :queue_name, :queue_binding]
      end

      
      def self.default_options
        {
          :host     => 'localhost',
          :port     => 5672,
          :insist   => true,
          :vhost    => '/',
          :username => 'guest',
          :password => 'guest',

          # If a queue is created, these are the default parameters
          # for said queue type
          :queue_passive     => false,
          :queue_durable     => true,
          :queue_exclusive   => false,
          :queue_auto_delete => false,
          :queue_nowait      => true,
        }
      end

    end
  end
end

