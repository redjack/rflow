class RFlow
  class Component

    module ConnectionCollection
      def send_message(message)
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
        @by_type = Hash.new {|hash, key| hash[key.to_s] = []}
      end

      def <<(port)
        by_uuid[port.instance_uuid.to_s] = port
        by_name[port.name.to_s] = port
        by_type[port.class.to_s] << port
        ports << port
        self
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
    

    # Bare superclass for (potential) later methods.  Currently empty
    class Port; end

    
    # Allows for a list of connections to be assigned to each port/key
    # combination.  Note that binding an input port to an un-indexed
    # output port will result in messages from all indexed connections
    # being received.  Similarly, sending to an unindexed port will
    # result in the same message being sent to all indexed
    # connections.
    class HashPort < Port
      attr_reader :name, :instance_uuid, :options, :connections_for
      
      def initialize(name, instance_uuid, options={})
        @name = name
        @instance_uuid = instance_uuid
        @connections_for = Hash.new {|hash, key| hash[key] = Array.new.extend(ConnectionCollection)}
      end


      def [](key)
        connections_for[key]
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

      
      # Send a message to all connections on all keys for this port,
      # but only once per connection.
      def send_message(message)
        all_connections.send_message(message)
      end
      

      # Should be overridden.  Called when it is time to actually
      # establish the connection
      def connect!; raise NotImplementedError, "Raw ports do not know which direction to connect"; end

      private

      def all_connections
        @all_connections ||= connections_for.map do |port_key, connections|
          connections
        end.flatten.uniq.extend(ConnectionCollection)
      end
      
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
        connections_for.each do |port_key, keyed_connections|
          keyed_connections.each do |connection|
            connection.connect_output!
          end
        end
        
        # Add the nil-keyed port to the all of the keyed connections
        connections_for.keys.each do |port_key|
          next unless port_key
          connections_for[port_key] += connections_for[nil]
          # TODO: make this better/easier
          connections_for[port_key].extend(ConnectionCollection)
        end
      end
    end

    class DisconnectedPort < HashPort; end
    
  end
end

__END__

out[even] -> a
out[odd]  -> b
out[nil]  -> c
