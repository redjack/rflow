class RFlow
  class Component

    module ConnectionCollection
      def send_message(message)
        puts "Sending message to connection collection"
        each do |connection|
          connection.send_message(message)
        end
      end
    end  

    # Collection class to make it easier to index by both names,
    # UUIDs, and types.
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


      # Enumerate through each connected (or disconnected but
      # referenced) port
      # TODO: simplify with enumerators and procs
      def each
        ports.each do |port|
          yield port
        end
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


      # Return a list of connected keys
      def keys
        connections_for.keys
      end


      # Enumerate through all the ConnectionCollections
      # TODO: simplify with enumerators and procs
      def each
        connections_for.values.each do |connections|
          yield connections
        end
      end


      # Send a message to all connections on all keys for this port.
      def send_message(message)
        connections_for.each do |port_key, connections|
          connections.send_message(message)
        end
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
