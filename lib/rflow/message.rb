require 'stringio'
require 'time'

require 'avro'

require 'rflow/configuration'

class RFlow

  # TODO: reduce reliance/expectation on avro serialization in method
  # names and such.
  class Message

    class << self
      def avro_message_schema; @avro_message_schema ||= Avro::Schema.parse(File.read(File.join(File.dirname(__FILE__), '..', '..', 'schema', 'message.avsc'))); end
      
      def avro_reader;  @avro_reader  ||= Avro::IO::DatumReader.new(avro_message_schema, avro_message_schema); end
      def avro_writer;  @avro_writer  ||= Avro::IO::DatumWriter.new(avro_message_schema); end
      def avro_decoder(io_object); Avro::IO::BinaryDecoder.new(io_object); end
      def avro_encoder(io_object); Avro::IO::BinaryEncoder.new(io_object); end

      # Take in an Avro serialization of a message and return a new
      # Message object.  Assumes the org.rflow.Message Avro schema.
      def from_avro(avro_serialized_message_byte_string)
        avro_serialized_message_byte_stringio = StringIO.new(avro_serialized_message_byte_string)
        message_hash = avro_reader.read avro_decoder(avro_serialized_message_byte_stringio)
        Message.new(message_hash['data_type_name'], message_hash['provenance'],
                    message_hash['data_serialization_type'], message_hash['data_schema'],
                    message_hash['data'])
      end
    end
    
    
    # Serialize the current message object to Avro using the
    # org.rflow.Message Avro schema.  Note that we have to manually
    # set the encoding for Ruby 1.9, otherwise the stringio would use
    # UTF-8 by default, which would not work correctly, as a serialize
    # avro string is BINARY, not UTF-8
    def to_avro
      avro_serialized_message_bytes = ''
      avro_serialized_message_bytes.force_encoding 'BINARY'
      avro_serialized_message_bytes_stringio = StringIO.new(avro_serialized_message_bytes, 'w')

      deserialized_avro_object = {
        'data_type_name' => self.data_type_name.to_s,
        'provenance' => self.provenance.map(&:to_hash),
        'data_serialization_type' => self.data.serialization_type.to_s,
        'data_schema' => self.data.schema_string,
        'data' => self.data.to_avro
      }

      self.class.avro_writer.write deserialized_avro_object, self.class.avro_encoder(avro_serialized_message_bytes_stringio)
      avro_serialized_message_bytes
    end
    

    attr_reader :data_type_name
    attr_accessor :processing_event
    attr_accessor :provenance
    attr_reader :data, :data_extensions

    
    def initialize(data_type_name, provenance=[], data_serialization_type='avro', data_schema_string=nil, serialized_data_object=nil)
      # Default the values, in case someone puts in a nil instead of
      # the default
      @data_type_name = data_type_name.to_s

      # Turn the provenance array of Hashes into an array of
      # ProcessingEvents for easier access and time validation.  TODO:
      # do this lazily so as not to create/destroy objects that are
      # never used
      @provenance = (provenance || []).map do |processing_event_hash_or_object|
        if processing_event_hash_or_object.is_a? ProcessingEvent
          processing_event_hash_or_object
        else
          ProcessingEvent.new(processing_event_hash_or_object['component_instance_uuid'],
                              processing_event_hash_or_object['started_at'],
                              processing_event_hash_or_object['completed_at'],
                              processing_event_hash_or_object['context'])
        end
      end
      
      # TODO: Make this better.  This check is technically
      # unnecessary, as we are able to completely desrialize the
      # message without needing to resort to the registered schema.
      registered_data_schema_string = RFlow::Configuration.available_data_types[@data_type_name][data_serialization_type.to_s]
      unless registered_data_schema_string
        error_message = "Data type '#{@data_type_name}' with serialization_type '#{data_serialization_type}' not found"
        RFlow.logger.error error_message
        raise ArgumentError, error_message
      end

      # TODO: think about registering the schemas automatically if not
      # found in Configuration
      if data_schema_string && (registered_data_schema_string != data_schema_string)
        error_message = "Passed schema ('#{data_schema_string}') does not equal registered schema ('#{registered_data_schema_string}') for data type '#{@data_type_name}' with serialization_type '#{data_serialization_type}'"
        RFlow.logger.error error_message
        raise ArgumentError, error_message
      end
      
      @data = Data.new(registered_data_schema_string, data_serialization_type.to_s, serialized_data_object)

      # Get the extensions and apply them to the data object to add capability
      @data_extensions = RFlow::Configuration.available_data_extensions[@data_type_name]
      @data_extensions.each do |data_extension|
        RFlow.logger.debug "Extending '#{data_type_name}' with extension '#{data_extension}'"
        @data.extend data_extension
      end
    end


    class ProcessingEvent
      attr_accessor :component_instance_uuid, :started_at, :completed_at, :context

      def initialize(component_instance_uuid, started_at=nil, completed_at=nil, context=nil)
        @component_instance_uuid = component_instance_uuid
        @started_at = case started_at
                      when String then Time.xmlschema(started_at) 
                      when Time   then started_at
                      else; nil; end
        @completed_at = case completed_at
                        when String then Time.xmlschema(completed_at) 
                        when Time   then completed_at
                        else; nil; end
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

      def initialize(schema_string, serialization_type='avro', serialized_data_object=nil)
        unless serialization_type == 'avro'
          error_message = "Only Avro serialization_type supported at the moment"
          RFlow.logger.error error_message
          raise ArgumentError, error_message
        end

        @schema_string = schema_string
        @serialization_type = serialization_type

        begin
          @schema = Avro::Schema.parse(schema_string)
        rescue Exception => e
          error_message = "Invalid schema '#{@schema_string}': #{e}: #{e.message}"
          RFlow.logger.error error_message
          raise ArgumentError, error_message
        end
        
        if serialized_data_object
          serialized_data_object.force_encoding 'BINARY'
          avro_decoder = Avro::IO::BinaryDecoder.new StringIO.new(serialized_data_object)
          @data_object = Avro::IO::DatumReader.new(schema, schema).read avro_decoder
        end
      end

      def valid?
        Avro::Schema.validate @schema, @data_object
      end
      
      def to_avro
        serialized_data_object_bytes = ''
        serialized_data_object_bytes.force_encoding 'BINARY'
        serialized_data_object_bytes_stringio = StringIO.new(serialized_data_object_bytes)
        Avro::IO::DatumWriter.new(@schema).write @data_object, Avro::IO::BinaryEncoder.new(serialized_data_object_bytes_stringio)
        serialized_data_object_bytes
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
