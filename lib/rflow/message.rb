class RFlow
  class Message
    class Data
      def self.inherited(subclass)
        RFlow.logger.debug "Found data extension #{subclass.name}"
        RFlow::Configuration.add_available_data_extension subclass
      end
      
      def initialize(data_type_name, serialized_data=nil, schema_type=nil, schema_name=nil, schema=nil)
        # Make sure that the schema is consistent
        registered_schema = RFlow.available_data_schemas[data_type_name]

        
        if registered_schema.nil? && schema
          # If you were given a schema and didn't get one from the
          # registry register the schema?
          self.class.schema_registry.register(data_type_name, schema_name, schema_type, schema)
        else
        end
      end
      
      def self.create(data_type_name, data=nil, schema_name=nil, schema_type=nil, schema=nil)
        # look for object in registry by data_type_name
        # if object found, call new on that object
        # otherwise, call new on the default object
        message_class = self.class.data_class_registry.find(data_type_name)
        if message_class.nil?
          MessageData.new(data_type_name, data, schema_name, schema_type, schema)
        else
          message_class.create(data_type_name, data, schema_name, schema_type, schema)
        end
      end

      # TODO: Sublcass for each schema type, Avro and XML
      class Schema
        attr_reader :name, :type, :data

        def initialize(name, type, data)
          @name = name
          @type = type
          @data = data
        end

        def data_type_name
          "DATA:" + @name
        end
      end
      
      class AvroSchema < Schema
        def initialize(name, data)
          super(name, self.class.name, data)
        end
      end
    end
  end
end
