class RFlow
  class Connection
    attr_accessor :instance_uuid, :configuration

    def initialize(connection_instance_uuid, connection_configuration={})
      @instance_uuid = connection_instance_uuid
      @configuration = connection_configuration
    end

    def connect!(direction)
      case direction
      when :input
        connect_input!
      when :output
        connect_output!
      else
        raise ArgumentError, "A connection can only connect in the :input or :output direction"
      end
    end

    # Subclass and implement to be able to handle future 'recv'
    # methods.  Will only be called in the context of a running
    # EventMachine reactor
    def connect_input!; raise NotImplementedError, "Raw connections do not support connect_input.  Please subclass and define a connect_output method."; end

    # Subclass and implement to be able to handle future 'send'
    # methods.  Will only be called in the context of a running
    # EventMachine reactor
    def connect_output!; raise NotImplementedError, "Raw connections do not support connect_output.  Please subclass and define a connect_output method."; end

    def send_message(message); raise NotImplementedError, "Raw connections do not support send_message.  Please subclass and define a send_message method."; end
    
    
  end # class Connection
end # class RFlow
