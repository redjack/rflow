class RFlow
  class Component

    module ConnectionCollection
      def send_message(message)
        each do |connection|
          connection.send_message(message)
        end
      end
    end  

    # To make it easier to index by both names and UUID.  Assuming
    # that ta port will never be named a UUID
    class PortCollection
      attr_reader :ports, :by_uuid, :by_name, :by_type

      def initialize
        @ports = Array.new
        @by_uuid = Hash.new
        @by_name = Hash.new
        @by_type = Hash.new {|hash, key| hash[key.to_s.to_sym] = []}
      end

      def <<(port)
        by_uuid[port.instance_uuid.to_s.to_sym] = port
        by_name[port.name.to_s.to_sym] = port
        by_type[port.class.to_s.to_sym] << port
        ports << port
      end

      def each
        ports.each
      end
    end
    
    
    class Port; end

    
    # Allows for a list of connections to be assigned to each port/key combination
    class HashPort
      attr_reader :name, :instance_uuid, :options, :connections_for
      
      def initialize(name, instance_uuid, options={})
        @name = name
        @instance_uuid = instance_uuid
        @connections_for = Hash.new {|hash, key| hash[key] = Array.new.extend(ConnectionCollection)}
      end

      def [](key)
        connections_for[key.to_s.to_sym]
      end


      def keys
        connections_for.keys
      end

      
      # Should be overridden.  Called when it is time to actually
      # establish the connection
      def connect!; raise NotImplementedError, "Raw ports do not know which direction to connect"; end

    end

    
    class InputPort < HashPort
      def connect!
        connections_for.each do |port_key, connections|
          connections.each do |connection|
            connection.connect_input!
          end
        end
      end
    end

    
    class OutputPort < HashPort
      def connect!
        connections_for.each do |port_key, scoped_connections|
          scoped_connections.each do |connection|
            connection.connect_output!
          end
        end
      end
    end

    class DisconnectedPort < HashPort; end
    
  end
end
