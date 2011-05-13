class RFlow
  class Connection
    attr_accessor :instance_uuid, :name, :configuration, :recv_callback

    # Attribute that holds the 
    attr_accessor :recv_callback
    
    def initialize(connection_instance_uuid, connection_name=nil, connection_configuration={})
      @instance_uuid = connection_instance_uuid
      @name = connection_name
      @configuration = connection_configuration
    end


    # Subclass and implement to be able to handle future 'recv'
    # methods.  Will only be called in the context of a running
    # EventMachine reactor
    def connect_input!; raise NotImplementedError, "Raw connections do not support connect_input.  Please subclass and define a connect_output method."; end


    # Subclass and implement to be able to handle future 'send'
    # methods.  Will only be called in the context of a running
    # EventMachine reactor
    def connect_output!; raise NotImplementedError, "Raw connections do not support connect_output.  Please subclass and define a connect_output method."; end

    
    # Subclass and implement to handle outgoing messages
    def send_message(message); raise NotImplementedError, "Raw connections do not support send_message.  Please subclass and define a send_message method."; end

    # Parent component should set this if connected.  Connection
    # subclass should call it (recv_callback.call(message)) when it
    # gets a new message, which will be transmitted back to the parent
    # component's process_message method
    def recv_callback; @recv_callback ||= Proc.new {}; end
    
  end # class Connection

  class Disconnection < Connection
    def send_message(message)
      RFlow.logger.debug "Attempting to send without a connection, doing nothing"
    end
  end
  
end # class RFlow
