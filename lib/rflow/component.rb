require 'rflow/message'

class RFlow
  class Component
    # Keep track of available component subclasses
    def self.inherited(subclass)
      RFlow.logger.debug "Found component #{subclass.name}"
      RFlow::Configuration.add_available_component(subclass)
    end

    class Port;
      attr_reader :name, :incidence

      def initialize(name, incidence)
        @name = name
        @incidence = incidence
      end
    end

    class InputPort
      def recv_message(message)
        puts "receiving message"
      end
    end

    class OutputPort
      attr_accessor :incidence
      
      def send_message(message)
        puts "sending message"
      end
    end
    
    
    # The class methods used in the creation of a component
    class << self
      attr_accessor :input_ports
      attr_accessor :output_ports

      attr_accessor :management_bus

      # TODO: Update the class vs instance stuffs here to be correct
      
      def input_port(name)
        port(input_ports, InputPort, name)
      end

      def output_port(name)
        port(output_ports, OutputPort, name)
      end

      def port(collection, klass, name)
        collection ||= []
        incidence = :single

        if name.is_a? Array
          incidence = :array
          name = name.first
        end
        port = klass.new(name.to_sym, incidence)
        collection << port

        define_method name.to_sym do |args|
          puts "#{name} called"
        end
      end
    end

    def configure
    end


    # Do stuff related before the process_message subclass method is called
    def pre_process_message(input_port, message)
      # Start updating the provenance with the start time
    end
    
    # Designed to be abstract
    def process_message(input_port, message); end
    
    # Do stuff related after the process_message subclass method is called
    def post_process_message(input_port, message); end
    
    # Main component running method.  Called 
    def run
      select(input_ports, output_ports) do |ready|
        if ready.input?
          message = read_message(ready)
          pre_process_message(ready_message)
          process_message(ready, message)
          post_process_message(ready, message)
        elsif ready.output?
        end
      end
      
    end
    
  end # class Component
end # class RFlow
