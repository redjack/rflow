class RFlow
  class Component

    # TODO: make this into a class to limit the amount of extensions
    # that we have to do when operating on these "Arrays", i.e. when
    # adding two together
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


    class Port
      attr_reader :connected
      def connected?; @connected; end
    end


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


      # Returns an extended Array of all the connections that should
      # be sent/received on this port.  Merges the nil-keyed port
      # (i.e. any connections for a port without a key) to those
      # specific for the key, so should only be used to read a list of
      # connections, not to add new ones.  Use add_connection to add a
      # new connection for a given key.
      def [](key)
         (connections_for[key] + connections_for[nil]).extend(ConnectionCollection)
      end


      # Adds a connection for a given key
      def add_connection(key, connection)
        connections_for[key] << connection
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
            @connected = true
          end
        end
      end
    end


    class OutputPort < HashPort
      def connect!
        connections_for.each do |port_key, keyed_connections|
          keyed_connections.each do |connection|
            connection.connect_output!
            @connected = true
          end
        end
      end
    end


    class DisconnectedPort < HashPort; end

  end
end
