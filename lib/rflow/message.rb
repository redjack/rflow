require 'stringio'
require 'avro'

require 'rflow/configuration'

class RFlow
  class Message

    class << self
      def message_avro_schema; @message_avro_schema ||= Avro::Schema.parse(File.read(File.join(File.basename(__FILE__), '..', '..', 'schema', 'message.avsc'))); end
      
      def avro_reader;  @avro_reader  ||= Avro::IO::DatumReader(message_avro_schema, message_avro_schema); end
      def avro_writer;  @avro_writer  ||= Avro::IO::DatumWriter.new(message_avro_schema); end
      def avro_decoder(io_object); Avro::IO::BinaryDecoder.new(io_object); end
      def avro_encoder(io_object); Avro::IO::BinaryEncoder.new(io_object); end

      # Take in an Avro serialization of a message and return a new
      # Message object.  Assumes the org.rflow.Message Avro schema.
      def from_avro(avro_serialized_message_byte_string)
        avro_serialized_message_byte_stringio = StringIO.new(avro_serialized_message_byte_string)
        avro_serialized_message_byte_stringio.binmode
        avro_reader.read avro_decoder(avro_serialized_message_byte_string)
      end
    end
    
    
    # Serialize the current message object to Avro using the
    # org.rflow.Message Avro schema.
    def to_avro
      avro_serialized_message_bytes_stringio = StringIO.new
      avro_serialized_message_bytes_stringio.binmode

      deserialized_avro_object = {
        'data_type_name' => self.data_type_name,
        'provenance' => self.provenance,
        'data_serialization' => self.data_serialization,
        'data_schema' => self.data_schema,
        'data' => self.data
      }

      self.class.avro_writer.write deserialized_avro_object, self.class.avro_encoder(avro_serialized_message_bytes_stringio)
      avro_serialized_message_bytes_stringio.string
    end
    

    attr_accessor :data_type_name, :provenance
    attr_accessor :data_serialization, :data_schema, :data
    attr_accessor :data_extensions
    
    def initialize(data_type_name, data_serialization=:avro)
      @data_type_name = data_type_name.to_sym
      @data_serialization = data_serialization.to_sym
      @data_schema = RFlow::Configuration.available_data_types[@data_type_name][@data_serialization]

      unless @data_schema
        error_message = "Data type '#{@data_type_name}' with serialization '#{@data_serialization}' not found"
        RFlow.logger.error error_message
        raise ArgumentError, error_message
      end
      
      @data = Data.new(@data_serialization, @data_schema)

      # Get the extensions and apply them to the data object to add capability
      RFlow::Configuration.available_data_extensions[@data_type_name].each do |data_extension|
        @data.extend data_extensions
      end
    end
    

    class Data

#      def initialize(data_type_name, serialized_data=nil, schema_type=nil, schema_name=nil, schema=nil)
#        # Make sure that the schema is consistent
#        registered_schema = RFlow.available_data_schemas[data_type_name]
#
#        
#        if registered_schema.nil? && schema
#          # If you were given a schema and didn't get one from the
#          # registry register the schema?
#          self.class.schema_registry.register(data_type_name, schema_name, schema_type, schema)
#        else
#        end
#      end
#      
#      def self.create(data_type_name, data=nil, schema_name=nil, schema_type=nil, schema=nil)
#        # look for object in registry by data_type_name
#        # if object found, call new on that object
#        # otherwise, call new on the default object
#        message_class = self.class.data_class_registry.find(data_type_name)
#        if message_class.nil?
#          MessageData.new(data_type_name, data, schema_name, schema_type, schema)
#        else
#          message_class.create(data_type_name, data, schema_name, schema_type, schema)
#        end
#      end
#
#      # TODO: Sublcass for each schema type, Avro and XML
#      class Schema
#        attr_reader :name, :type, :data
#
#        def initialize(name, type, data)
#          @name = name
#          @type = type # should be :avro or :xml
#          @data = data
#        end
#
#        def data_type_name
#          "DATA:" + @name
#        end
#      end
#      
#      class AvroSchema < Schema
#        def initialize(name, data)
#          super(name, self.class.name, data)
#        end
#      end
    end
  end
end
