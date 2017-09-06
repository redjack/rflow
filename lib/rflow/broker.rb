require 'rflow/child_process'

class RFlow
  # A message broker process to mediate messages along a connection.
  # The broker runs in a child process and will not return from {spawn!}.
  class Broker < ChildProcess
    class << self
      # Build the broker from the connection configuration.
      # Only supports {RFlow::Configuration::ZMQStreamer} configurations.
      # @param config [RFlow::Configuration::ZMQStreamer] the connection configuration
      # @return [RFlow::Connections::ZMQStreamer]
      def build(config)
        case config.class.name
        when 'RFlow::Configuration::ZMQStreamer'
          RFlow::Connections::ZMQStreamer.new(config)
        else
          raise ArgumentError, 'Only ZMQ brokers currently supported'
        end
      end
    end
  end
end
