require 'rflow/message'

class RFlow
  class Connection
    class << self
      def build(config)
        case config.type
        when 'RFlow::Configuration::ZMQConnection'
          RFlow::Connections::ZMQConnection.new(config)
        else
          raise ArgumentError, "Only ZMQConnections currently supported"
        end
      end
    end

    attr_accessor :config, :uuid, :name, :options
    attr_accessor :recv_callback

    def initialize(config)
      @config = config
      @uuid = config.uuid
      @name = config.name
      @options = config.options
    end

    # Subclass and implement to be able to handle future 'recv'
    # methods.  Will only be called in the context of a running
    # EventMachine reactor
    def connect_input!
      raise NotImplementedError, "Raw connections do not support connect_input.  Please subclass and define a connect_output method."
    end

    # Subclass and implement to be able to handle future 'send'
    # methods.  Will only be called in the context of a running
    # EventMachine reactor
    def connect_output!
      raise NotImplementedError, "Raw connections do not support connect_output.  Please subclass and define a connect_output method."
    end

    # Subclass and implement to handle outgoing messages.  The message
    # will be a RFlow::Message object and the subclasses are expected
    # to marshal it up into something that will be unmarshalled on the
    # other side
    def send_message(message)
      raise NotImplementedError, "Raw connections do not support send_message.  Please subclass and define a send_message method."
    end

    # Parent component will set this attribute if it expects to
    # recieve messages.  Connection subclass should call it
    # (recv_callback.call(message)) when it gets a new message, which
    # will be transmitted back to the parent component's
    # process_message method.  Sublcass is responsible for
    # deserializing whatever was on the wire into a RFlow::Message object
    def recv_callback
      @recv_callback ||= Proc.new {|message|}
    end
  end

  class Disconnection < Connection
    def send_message(message)
      RFlow.logger.debug "Attempting to send without a connection, doing nothing"
    end
  end
end
