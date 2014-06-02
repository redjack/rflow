class RFlow
  module Components
    class Clock < Component
      module Tick
        SCHEMA_DIRECTORY = ::File.expand_path(::File.join(::File.dirname(__FILE__), '..', '..', '..', 'schema'))
        SCHEMA_FILES = {'tick.avsc' => 'RFlow::Message::Clock::Tick'}
        SCHEMA_FILES.each do |file_name, data_type_name|
          schema_string = ::File.read(::File.join(SCHEMA_DIRECTORY, file_name))
          RFlow::Configuration.add_available_data_type data_type_name, 'avro', schema_string
        end
        module Extension
          def self.extended(base_data); base_data.data_object ||= {}; end
          def name; data_object['name']; end
          def name=(new_name); data_object['name'] = new_name; end
          def timestamp; data_object['timestamp']; end
          def timestamp=(new_ts); data_object['timestamp'] = new_ts; end
        end
        RFlow::Configuration.add_available_data_extension('RFlow::Message::Clock::Tick', Extension)
      end

      output_port :tick_port

      DEFAULT_CONFIG = {
        'name' => 'Clock',
        'tick_interval' => 1
      }

      attr_reader :config, :tick_interval

      def configure!(config)
        @config = DEFAULT_CONFIG.merge config
        @tick_interval = Float(@config['tick_interval'])
      end

      def clock_name; config['name']; end

      def run!
        @timer = EventMachine::PeriodicTimer.new(tick_interval) { tick }
      end

      def tick
        tick_port.send_message(RFlow::Message.new('RFlow::Message::Clock::Tick').tap do |m|
          m.data.name = clock_name
          m.data.timestamp = Integer(Time.now.to_f * 1000) # ms since epoch
        end)
      end
    end
  end
end
