class RFlow
  class Component
    class Port; end
    
    class HashPort
      attr_reader :name, :instance_uuid, :options, :connections
      
      def initialize(name, instance_uuid, options={})
        @name = name
        @instance_uuid = instance_uuid
        @connections = Hash.new
      end

      def [](key)
        connections[key.to_s.to_sym]
      end

      def []=(key, connection)
        connections[key.to_s.to_sym] = connection
      end

      def each
        connections.each
      end
      
      # Should be overridden.  Called when it is time to actually
      # establish the connection
      def connect!; raise NotImplementedError, "Raw ports do not know which direction to connect"; end

    end

    
    class InputPort < HashPort
      def connect!
        connections.each do |port_key, connection|
          connection.connect_input!
        end
      end
    end

    
    class OutputPort < HashPort
      def connect!
        connections.each do |port_key, connection|
          connection.connect_output!
        end
      end
    end

  end
end
