class RFlow
  class Component
    # TODO: make this into a class to limit the amount of extensions
    # that we have to do when operating on these 'Arrays', i.e. when
    # adding two together
    # @!visibility private
    module ConnectionCollection
      # @!visibility private
      def send_message(message)
        each {|connection| connection.send_message(message) }
      end
    end

    # Collection class to make it easier to index by both names
    # and types.
    class PortCollection
      # All the ports in the collection.
      # @return [Array<Port>]
      attr_reader :ports
      # All the ports in the collection, indexed by name.
      # @return [Hash<String, Port>]
      attr_reader :by_name
      # All the ports in the collection, indexed by type ({InputPort}, {OutputPort}).
      # @return [Hash<String, Array<Port>>]
      attr_reader :by_type

      def initialize
        @ports = []
        @by_name = {}
        @by_type = Hash.new {|hash, key| hash[key.to_s] = []}
      end

      # Add a port to the collection.
      # @param port [Port] port to add
      # @return [PortCollection] self
      def <<(port)
        by_name[port.name.to_s] = port
        by_type[port.class.to_s] << port
        ports << port
        self
      end

      # Enumerate through each port, +yield+ing each.
      # TODO: simplify with enumerators and procs
      # @return [Array<Port>]
      def each
        ports.each {|port| yield port }
      end
    end

    # An input or output port on a {Component}.
    class Port
      # True if there are connections to the port.
      # @return [boolean]
      attr_reader :connected
      # The {Component} this port belongs to.
      # @return [Component]
      attr_reader :component

      def initialize(component)
        @component = component
      end

      # Synonym for {connected}.
      # @return [boolean]
      def connected?; connected; end
    end

    # Represents a keyed subport on a {Component} - that is, an input or output port
    # that has been subscripted with a port name for subdividing the messages being
    # received or output.
    class HashSubPort
      # @param hash_port [HashPort] the port to which this subport belongs
      # @param key [String] the key subscript
      def initialize(hash_port, key)
        @hash_port = hash_port
        @key = key
      end

      # Send a {Message} down all the connections to this subport.
      # @param message [Message]
      # @return [void]
      def send_message(message)
        connections.each {|connection| connection.send_message(message) }
      end

      # Retrieve all the connections for this subport.
      # @return [Array<Connection>]
      def connections
        @hash_port.connections_for(@key)
      end

      # Directly connect this subport to another port.
      # @param other_port [Port] the other port to connect to
      # @return [void]
      def direct_connect(other_port)
        @hash_port.direct_connect(@key, other_port)
      end

      # Enumerate the connections to this subport, +yield+ing each.
      # @return [Array<Connection>]
      def each
        connections.each {|connection| yield connection }
      end
    end

    # Allows for a list of connections to be assigned to each port/key
    # combination.  Note that binding an input port to an un-indexed
    # output port will result in messages from all indexed connections
    # being received.  Similarly, sending to an unindexed port will
    # result in the same message being sent to all indexed
    # connections.
    class HashPort < Port
      # The name of the port.
      # @return [String]
      attr_accessor :name
      # The UUID of the port.
      # @return [String]
      attr_accessor :uuid

      public
      # @param component [Component] the component the port belongs to
      # @param args [Hash] supported args are +:uuid+ and +:name+
      def initialize(component, args = {})
        super(component)
        self.uuid = args[:uuid]
        self.name = args[:name]
        @connections_for = Hash.new {|hash, key| hash[key] = []}
      end

      # Get the subport for a given key, which can be used to send messages
      # or direct connection.
      # @param key [String] the key to subscript with
      # @return [HashSubPort]
      def [](key)
        HashSubPort.new(self, key)
      end

      # Returns all the connections that should
      # be sent/received on this subport.  Merges the +nil+-keyed port
      # (i.e. any connections for a port without a key) to those
      # specific for the key, so should only be used to read a list of
      # connections, not to add new ones.  Use {add_connection} to add a
      # new connection for a given key.
      # @param key [String] the key to subscript with
      # @return [Array<Connection>]
      def connections_for(key)
        case key
        when nil; @connections_for[nil]
        else @connections_for[key] + @connections_for[nil]
        end
      end

      # Adds a connection for a given key.
      # @param key [String] the key to subscript with
      # @param connection [Connection] the connection to add
      # @return [void]
      def add_connection(key, connection)
        RFlow.logger.debug "Attaching #{connection.class.name} connection '#{connection.name}' (#{connection.uuid}) to port '#{name}' (#{uuid}), key '#{connection.input_port_key}'"
        @connections_for[key] << connection
        @all_connections = nil
      end

      # Removes a connection from a given key.
      # @param key [String] the key to subscript with
      # @param connection [Connection] the connection to remove
      # @return [void]
      def remove_connection(key, connection)
        RFlow.logger.debug "Removing #{connection.class.name} connection '#{connection.name}' (#{connection.uuid}) from port '#{name}' (#{uuid}), key '#{connection.input_port_key}'"
        @connections_for[key].delete(connection)
        @all_connections = nil
      end

      # Collect messages being sent to this port in a {MessageCollectingConnection}
      # for retrieval later, usually for unit testing purposes. +yield+s after
      # establishing the new connection.
      # @param key [String] the key to subscript with
      # @param receiver [Array] array in which to place arriving messages
      # @return [MessageCollectingConnection]
      def collect_messages(key, receiver)
        begin
          connection = RFlow::MessageCollectingConnection.new.tap do |c|
            c.messages = receiver
          end
          add_connection key, connection

          yield if block_given?
          connection
        ensure
          remove_connection key, connection if connection && block_given?
        end
      end

      # Directly connect this port to another port. If it's an input port,
      # forward messages to that input port; if it's an output port,
      # forward messages so they appear to come from that output port.
      # @param key [String] the key to subscript with
      # @param other_port [Port] the port to forward to
      # @return [void]
      def direct_connect(key = nil, other_port)
        case other_port
        when InputPort; add_connection key, ForwardToInputPort.new(other_port)
        when OutputPort; add_connection key, ForwardToOutputPort.new(other_port)
        else raise ArgumentError, "Unknown port type #{other_port.class.name}"
        end
      end

      # A list of connected keys.
      # @return [Array<String>]
      def keys
        @connections_for.keys
      end

      # Enumerate all connections, +yield+ing each.
      # @return [Array<Connection>]
      def each
        @connections_for.values.each {|connections| yield connections }
      end

      # Override in subclasses to actually send messages places.
      # @param message [Message] the message to send
      # @return [void]
      def send_message(message)
        raise NotImplementedError, 'Raw ports do not know how to send messages'
      end

      # Override in subclasses to handle establishing the connection.
      # @return [void]
      def connect!; raise NotImplementedError, 'Raw ports do not know which direction to connect'; end

      # Retrieve all connections to the port, regardless of key. The resulting +Array+
      # also supports +send_message(message)+ which will deliver the message on all
      # connections.
      # @return [Array<Connection>]
      def all_connections
        @all_connections ||= @connections_for.values.flatten.uniq.extend(ConnectionCollection)
      end
    end

    # An actual {Component} input port.
    class InputPort < HashPort
      # Connect all the input connections, once everything's been set up.
      # @return [void]
      def connect!
        @connections_for.each {|key, conns| conns.each {|c| c.connect_input! } }
        @connected = true
      end

      # Add and start up a new {Connection}.
      # @param key [String] the key to subscript with
      # @param connection [Connection] the connection to add
      # @return [void]
      def add_connection(key, connection)
        super
        connection.connect_input! if connected?
      end

      # Once things have been set up, registering the receive callback
      # will set it on all connections, so that when messages are received,
      # they are delivered on all connections with appropriate key and connection
      # information from the context of the connection.
      # @param callback [Proc] the receive callback
      # @return [void]
      def recv_callback=(callback)
        @connections_for.each do |key, connections|
          connections.each do |connection|
            connection.recv_callback = Proc.new do |message|
              callback.call self, key, connection, message
            end
          end
        end
      end
    end

    # An actual {Component} output port.
    class OutputPort < HashPort
      # Connect all the output connections, once everything's been set up.
      # @return [void]
      def connect!
        @connections_for.each {|key, conns| conns.each {|c| c.connect_output! } }
        @connected = true
      end

      # Add and start up a new {Connection}.
      # @param key [String] the key to subscript with
      # @param connection [Connection] the connection to add
      # @return [void]
      def add_connection(key, connection)
        super
        connection.connect_output! if connected?
      end

      # Send a message to all connections on all keys for this port,
      # but only once per connection.
      # @param message [RFlow::Message] the message to send
      # @return [void]
      def send_message(message)
        all_connections.send_message(message)
      end
    end
  end
end
