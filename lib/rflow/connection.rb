class RFlow
  class Connection

    def initialize(connection_type, connection_options)
    end

  end # class Connection


  class RFlow::Connections::ZMQConnection < Connection
  end

  class RFlow::Connections::AMQPConnection < Connection
  end
      
end # class RFlow
