require 'stringio'
require 'time'
require 'avro'
require 'rflow/configuration'

class RFlow
  class Avro
    def self.decode(reader, bytes)
      reader.read ::Avro::IO::BinaryDecoder.new(StringIO.new(bytes.force_encoding('BINARY')))
    end

    def self.encode(writer, message)
      String.new.force_encoding('BINARY').tap do |result|
        writer.write message, ::Avro::IO::BinaryEncoder.new(StringIO.new(result, 'w'))
      end
    end
  end

  class Message
    class << self
      def schema; @schema ||= ::Avro::Schema.parse(File.read(File.join(File.dirname(__FILE__), '..', '..', 'schema', 'message.avsc'))); end
      def message_reader; @message_reader ||= ::Avro::IO::DatumReader.new(schema, schema); end
      def message_writer; @message_writer ||= ::Avro::IO::DatumWriter.new(schema); end
      def encode(message); RFlow::Avro.encode(message_writer, message); end

      # Take in an Avro serialization of a message and return a new
      # Message object.  Assumes the org.rflow.Message Avro schema.
      def from_avro(bytes)
        message = RFlow::Avro.decode(message_reader, bytes)
        Message.new(message['data_type_name'], message['provenance'], message['properties'],
                    message['data_serialization_type'], message['data_schema'],
                    message['data'])
      end
    end

    attr_accessor :provenance, :properties
    attr_reader :data_type_name, :data

    # When creating a new message as a transformation of an existing
    # message, its encouraged to copy the provenance and properties of
    # the original message into the new message. This allows
    # downstream components to potentially use these fields
    def initialize(data_type_name, provenance = [], properties = {}, serialization_type = 'avro', schema = nil, serialized_data = nil)
      @data_type_name = data_type_name.to_s

      # Turn the provenance array of Hashes into an array of
      # ProcessingEvents for easier access and time validation.
      # TODO: do this lazily so as not to create/destroy objects that are
      # never used
      @provenance = (provenance || []).map do |event|
        if event.is_a? ProcessingEvent
          event
        else
          ProcessingEvent.new(event['component_instance_uuid'],
                              event['started_at'], event['completed_at'],
                              event['context'])
        end
      end

      @properties = properties || {}

      # TODO: Make this better.  This check is technically
      # unnecessary, as we are able to completely deserialize the
      # message without needing to resort to the registered schema.
      registered_schema = RFlow::Configuration.available_data_types[@data_type_name][serialization_type.to_s]
      unless registered_schema
        raise ArgumentError, "Data type '#{@data_type_name}' with serialization_type '#{serialization_type}' not found"
      end

      # TODO: think about registering the schemas automatically if not
      # found in Configuration
      if schema && (registered_schema != schema)
        raise ArgumentError, "Passed schema ('#{schema}') does not equal registered schema ('#{registered_schema}') for data type '#{@data_type_name}' with serialization_type '#{serialization_type}'"
      end

      @data = Data.new(registered_schema, serialization_type.to_s, serialized_data)

      # Get the extensions and apply them to the data object to add capability
      RFlow::Configuration.available_data_extensions[@data_type_name].each do |e|
        RFlow.logger.debug "Extending '#{data_type_name}' with extension '#{e}'"
        @data.extend e
      end
    end

    # Serialize the current message object to Avro using the
    # org.rflow.Message Avro schema.  Note that we have to manually
    # set the encoding for Ruby 1.9, otherwise the stringio would use
    # UTF-8 by default, which would not work correctly, as a serialize
    # avro string is BINARY, not UTF-8
    def to_avro
      # stringify all the properties
      string_properties = Hash[properties.map { |k,v| [k.to_s, v.to_s] }]

      Message.encode('data_type_name' => data_type_name.to_s,
                     'provenance' => provenance.map(&:to_hash),
                     'properties' => string_properties.to_hash,
                     'data_serialization_type' => data.serialization_type.to_s,
                     'data_schema' => data.schema_string,
                     'data' => data.to_avro)
    end

    class ProcessingEvent
      attr_reader :component_instance_uuid, :started_at
      attr_accessor :completed_at, :context

      def initialize(component_instance_uuid, started_at = nil, completed_at = nil, context = nil)
        @component_instance_uuid = component_instance_uuid
        @started_at = case started_at
                      when String; Time.xmlschema(started_at)
                      when Time; started_at
                      else nil; end
        @completed_at = case completed_at
                        when String; Time.xmlschema(completed_at)
                        when Time; completed_at
                        else nil; end
        @context = context
      end

      def to_hash
        {
          'component_instance_uuid' => component_instance_uuid.to_s,
          'started_at'   => started_at   ? started_at.xmlschema(6)   : nil,
          'completed_at' => completed_at ? completed_at.xmlschema(6) : nil,
          'context'      => context      ? context.to_s              : nil,
        }
      end
    end

    # Should proxy most methods to data_object that we can serialize
    # to avro using the schema.  Extensions should use 'extended' hook
    # to apply immediate changes.
    class Data
      attr_reader :schema_string, :schema, :serialization_type
      attr_accessor :data_object

      def initialize(schema_string, serialization_type = 'avro', serialized_data = nil)
        raise ArgumentError, 'Only Avro serialization_type supported at the moment' unless serialization_type.to_s == 'avro'

        @schema_string = schema_string
        @serialization_type = serialization_type.to_s

        begin
          @schema = ::Avro::Schema.parse(schema_string)
          @writer = ::Avro::IO::DatumWriter.new(@schema)
        rescue Exception => e
          raise ArgumentError, "Invalid schema '#{@schema_string}': #{e}: #{e.message}"
        end

        if serialized_data
          serialized_data.force_encoding 'BINARY'
          @data_object = RFlow::Avro.decode(::Avro::IO::DatumReader.new(schema, schema), serialized_data)
        end
      end

      def valid?
        ::Avro::Schema.validate @schema, @data_object
      end

      def to_avro
        RFlow::Avro.encode @writer, @data_object
      end

      # Proxy methods down to the underlying data_object, probably a
      # Hash.  Hopefully an extension will provide any additional
      # functionality so this won't be called unless needed
      def method_missing(method_sym, *args, &block)
        @data_object.send(method_sym, *args, &block)
      end
    end
  end
end
