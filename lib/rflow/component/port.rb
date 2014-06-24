class RFlow
  class Component
    # TODO: make this into a class to limit the amount of extensions
    # that we have to do when operating on these "Arrays", i.e. when
    # adding two together
    module ConnectionCollection
      def send_message(message)
        each {|connection| connection.send_message(message) }
      end
    end

    # Collection class to make it easier to index by both names
    # and types.
    class PortCollection
      attr_reader :ports, :by_name, :by_type

      def initialize
        @ports = []
        @by_name = {}
        @by_type = Hash.new {|hash, key| hash[key.to_s] = []}
      end

      def <<(port)
        by_name[port.name.to_s] = port
        by_type[port.class.to_s] << port
        ports << port
        self
      end

      # Enumerate through each port
      # TODO: simplify with enumerators and procs
      def each
        ports.each {|port| yield port }
      end
    end

    class Port
      attr_reader :connected, :component

      def initialize(component)
        @component = component
      end

      def connected?; connected; end
    end

    # Allows for a list of connections to be assigned to each port/key
    # combination.  Note that binding an input port to an un-indexed
    # output port will result in messages from all indexed connections
    # being received.  Similarly, sending to an unindexed port will
    # result in the same message being sent to all indexed
    # connections.
    class HashPort < Port
      attr_accessor :name, :uuid

      protected
      attr_reader :connections_for

      public
      def initialize(component, args = {})
        super(component)
        self.uuid = args[:uuid]
        self.name = args[:name]
        @connections_for = Hash.new {|hash, key| hash[key] = [].extend(ConnectionCollection)}
      end

      # Returns an extended Array of all the connections that should
      # be sent/received on this port.  Merges the nil-keyed port
      # (i.e. any connections for a port without a key) to those
      # specific for the key, so should only be used to read a list of
      # connections, not to add new ones.  Use add_connection to add a
      # new connection for a given key.
      def [](key)
        case key
        when nil; connections_for[nil]
        else connections_for[key] + connections_for[nil]
        end.extend(ConnectionCollection)
      end

      # Adds a connection for a given key
      def add_connection(key, connection)
        RFlow.logger.debug "Attaching #{connection.class.name} connection '#{connection.name}' (#{connection.uuid}) to port '#{name}' (#{uuid}), key '#{connection.input_port_key}'"
        connections_for[key] << connection
      end

      # Removes a connection from a given key
      def remove_connection(key, connection)
        RFlow.logger.debug "Removing #{connection.class.name} connection '#{connection.name}' (#{connection.uuid}) from port '#{name}' (#{uuid}), key '#{connection.input_port_key}'"
        connections_for[key].delete(connection)
      end

      def direct_connect(other_port)
        case other_port
        when InputPort; add_connection nil, ForwardToInputPort.new(other_port)
        when OutputPort; add_connection nil, ForwardToOutputPort.new(other_port)
        else raise ArgumentError, "Unknown port type #{other_port.class.name}"
        end
      end

      # Return a list of connected keys
      def keys
        connections_for.keys
      end

      # Enumerate through all the ConnectionCollections
      # TODO: simplify with enumerators and procs
      def each
        connections_for.values.each {|connections| yield connections }
      end

      def send_message(message)
        def connect!; raise NotImplementedError, "Raw ports do not know how to send messages"; end
      end

      # Should be overridden.  Called when it is time to actually
      # establish the connection
      def connect!; raise NotImplementedError, "Raw ports do not know which direction to connect"; end

      private
      def all_connections
        @all_connections ||= connections_for.values.flatten.uniq.extend(ConnectionCollection)
      end
    end

    class InputPort < HashPort
      def connect!
        connections_for.each do |key, connections|
          connections.each do |connection|
            connection.connect_input!
            @connected = true
          end
        end
      end

      def recv_callback=(callback)
        connections_for.each do |key, connections|
          connections.each do |connection|
            connection.recv_callback = Proc.new do |message|
              callback.call self, key, connection, message
            end
          end
        end
      end
    end

    class OutputPort < HashPort
      def connect!
        connections_for.each do |key, connections|
          connections.each do |connection|
            connection.connect_output!
            @connected = true
          end
        end
      end

      # Send a message to all connections on all keys for this port,
      # but only once per connection.
      def send_message(message)
        all_connections.send_message(message)
      end
    end
  end
end
