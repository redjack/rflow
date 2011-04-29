module RFlow
  def self.run(config)
    # Take in the config file
    # Set a module-level config
    # Set module-level attributes (logger)
    # Create manager
    # Start manager with parsed config elements
  end

  class Manager

    def initialize(config)
    end
    # Find each component
    # Instantiate (process management)
  end
end

class SchemaRegistry
  # maps data type names to schemas based on schema type
  find_by_data_type_name
end

class MessageDataRegistry
  def find(data_type_name)
    # returns a data type class if registered, nil otherwise
  end
end

class Message::Data
  # contains the schema + data information
  # subclasses can add extra functionality, otherwise will just have
  # acces to standard messagedata stuffs (i.e. standard avro data types)
  # delegates a lot to standard Avro types

  # how does this get access to the registry at the class level?
  class << self
    attr_accessor :class_registry
    attr_accessor :schema_registry
  end

  # Pointer to encapsulating message
  attr_accessor :message 
  
  def initialize(data_type_name, serialized_data=nil, schema_name=nil, schema_type=nil, schema=nil, message=nil)
    # schema_name ||= 'org.rflow.Messages.GenericStringMap'
    # schema_type ||= 'avro'
    # schema ||= 'default avro schema'

    merge_options

    # TODO: think about schema resolution and conflicts between passed
    # data and schema registry
    # Lookup schema based on data type name
    registered_schema_name, registered_schema, registered_schema_type = self.class.schema_registry.find(data_type_name)
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
end

module HTTPResponse
end

Message.new.extend(HTTPResponse)

class HTTPRequest < RFlow::Message::Data
  # used to add methods, defaults, and more to data object, if required

  # Put this in the registry
  AVRO_SCHEMA_NAME = 'org.rflow.http_request'
  DATA_TYPE_NAME = "HTTPRequest"

  # All subclasses must have the same initialize signature.  They need
  # to figure out what to do when they get the extra parameters that
  # might conflict with expectations.  Subclasses are usually meant to
  # enable extra functionality on a given data type, so as long as it
  # operates properly, it might not care (duck typing)
  def initialize(data_type_name, data, schema_name, schema_type, schema)
    super(DATA_TYPE_NAME, data, AVRO_SCHEMA_NAME)
    # do nice stuff with data here
  end

  def self.create(data_type_name, data, schema_name, schema_type, schema)
    # figure out if you are being called with incompatible arguments,
    # i.e. schema stuff
  end
  
end
  
class Message
  # contains all definitions about what to do for a message
  # has a default Avro schema for a data type

  class << self
    attr_accessor :data_class_registry
  end

  
  # Should load all the data stuff, perhaps to top level method on object

  attr_accessor :data_type_name, :provenance, :origination_context, :data_type_schema, :data

  def initialize(data_type_name, provenance=nil, origination_context=nil, data_type_schema=nil, data=nil)
    if data
      # Potentially register this data_type_name to the schema
    else
      # Lookup MessageData type in the MessageDataRegistry
      # if found and a class, create a specific MessageData object
      #   extend it with the module
      # else, create generic MessageData object which will use
      #   the schema registry, under the hood
      # if found and a module, extend object with found module

      message_data_class = self.class.data_class_registry.find(data_type_name)
      if message_data_class && message_data_class.class.is_a? Class
        message_data = message_data_class.new
      else
        message_data = Message::Data.new
        message_data.extend message_data_class if message_data_class.is_a? Module
      end
    end
  end
  
end

class Port
  def read_message
    parts = read_all_parts
    parts.assemble
    data_type_name = read_message_part
    provenance = read_message_part
    origination_context = read_message_part
    data_type_schema = read_message_part
    data = read_message_part

    message = Message.new(data_type_name, provenance, origination_context, data_type_schema, data)

    message
  end
end

class PortCollection
end

class Logger
end

class Component
  def self.input_port(port_def)
    @@input_ports ||= PortCollection.new
    if port_def.is_a? Array
      port_name = port_def.first.to_sym
      port_incidence = :array
    else
      port_name = port_def
      port_incidence = :single
    end
    @@input_ports[port_name] = InputPort.new port_name, port_incidence
  end 
  
  def self.output_port
    # same as input port with different stuffs
  end

  STATES = [:initialized, :started, :configured, :running, :stopping, :stopped]
  attr_accessor :state
  attr_accessor :input_ports
  attr_accessor :output_ports

  attr_accessor :uuid
  attr_accessor :name

  CONFIG_DEFAULTS = {
    :logger,
    :working_directory_path,
  }
  
  def initialize(config, run_directory)
    # configure component
    config = {
    }

    # TODO: where is the management bus listener configured/started
  end

  def run
    input_ports.ready do |port|
      message = port.read_message
      process_input(port, message)
      # read from the port and think about things
      out.send('stuff')
      another_out.send('more stuff')
    end
    # listen to 
  end

  def process_message(input_port, message)

  end

  def receive_message(port)
    port.receive
  end
  
  def send_message(port, message)
    port.send(message)
  end

end

class HTTPServer < RFlow::Component
  input_port :responses
  output_port :requests
  
  input_types "HTTP::Response"
  output_types "HTTP::Request"

  
end

class PassThrough < RFlow::Component
  input_port [:in]
  input_port :another_in
  output_port :out
  output_port :another_out

  output_types 
  
  def initialize(config, run_directory)
    # This will initialize the ports
    super
    # Do stuff to initialize component.  Don't assume singleton
  end   


  def process_message(input_port, data)
    out.send(message)
    another_out.send(message)

    
  end

  def process_data(input_port
  
end


class Transform < RFlow::Component
  
end

# Plugins:

# MessageData subclass: rflow-data-http_request
#  lib/rflow-data-http_request.rb
require 'rflow'
require 'lib/data_name'
RFlow.available_data_types << data_name_object


# Component: rflow-component-http_server
#   lib/rflow-component-http_server
require 'rflow'
require 'lib/component_name'
RFlow.available_components << component_class




#   lib/component_name.rb ->
# data_type_name => schema + registration: just register in the application



# Server -> (HttpRequest -> Translate -> HTTPResponse) -> Server


