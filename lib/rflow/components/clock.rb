class RFlow
  # @!parse
  #   class Message
  #     # Clock messages.
  #     module Clock
  #       # Message emitted by {RFlow::Components::Clock}. Of course the real class is {RFlow::Message}
  #       # with type +RFlow::Message::Clock::Tick+.
  #       class Tick
  #         # @!attribute name
  #         #   The name of the clock.
  #         #   @return [String]
  #
  #         # @!attribute timestamp
  #         #   The timestamp of the tick, in milliseconds from epoch.
  #         #   @return [Integer]
  #
  #         # Just here to force Yard to create documentation.
  #         # @!visibility private
  #         def initialize; end
  #       end
  #     end
  #   end

  # Components.
  module Components
    # A clock. It ticks every _n_ seconds. Get it?
    #
    # Accepts config parameters:
    # - +name+ - name of the clock, to disambiguate more than one
    # - +tick_interval+ - how long to wait between ticks
    #
    # Emits {RFlow::Message}s whose internal type is {RFlow::Message::Clock::Tick}.
    class Clock < Component
      # @!visibility private
      module Tick
        # @!visibility private
        SCHEMA_DIRECTORY = ::File.expand_path(::File.join(::File.dirname(__FILE__), '..', '..', '..', 'schema'))
        # @!visibility private
        SCHEMA_FILES = {'tick.avsc' => 'RFlow::Message::Clock::Tick'}
        SCHEMA_FILES.each do |file_name, data_type_name|
          schema_string = ::File.read(::File.join(SCHEMA_DIRECTORY, file_name))
          RFlow::Configuration.add_available_data_type data_type_name, 'avro', schema_string
        end
        # @!visibility private
        module Extension
          # @!visibility private
          def self.extended(base_data); base_data.data_object ||= {}; end
          # @!visibility private
          def name; data_object['name']; end
          # @!visibility private
          def name=(new_name); data_object['name'] = new_name; end
          # @!visibility private
          def timestamp; data_object['timestamp']; end
          # @!visibility private
          def timestamp=(new_ts); data_object['timestamp'] = new_ts; end
        end
        RFlow::Configuration.add_available_data_extension('RFlow::Message::Clock::Tick', Extension)
      end

      # @!attribute [r] tick_port
      #   Outputs {RFlow::Message::Clock::Tick} messages.
      #   @return [Component::OutputPort]
      output_port :tick_port

      # Default configuration.
      DEFAULT_CONFIG = {
        'name' => 'Clock',
        'tick_interval' => 1
      }

      # @!visibility private
      attr_reader :config, :tick_interval

      # RFlow-called method at startup.
      # @param config [Hash] configuration from the RFlow config file
      # @return [void]
      def configure!(config)
        @config = DEFAULT_CONFIG.merge config
        @tick_interval = Float(@config['tick_interval'])
      end

      # @!visibility private
      def clock_name; config['name']; end

      # RFlow-called method at startup.
      # @return [void]
      def run!
        @timer = EventMachine::PeriodicTimer.new(tick_interval) { tick }
      end

      # @!visibility private
      def tick
        tick_port.send_message(RFlow::Message.new('RFlow::Message::Clock::Tick').tap do |m|
          m.data.name = clock_name
          m.data.timestamp = Integer(Time.now.to_f * 1000) # ms since epoch
        end)
      end
    end
  end
end
