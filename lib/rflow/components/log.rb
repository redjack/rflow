class RFlow
  # @!parse
  #   class Message
  #     class Data
  #       # RFlow format defined for log messages which can be emitted by components.
  #       # Of course the real class is {RFlow::Message}
  #       # with type +RFlow::Message::Data::Log+.
  #       class Log
  #         # @!attribute timestamp
  #         #   The timestamp of the log, in ms since epoch.
  #         #   @return [Integer]
  #
  #         # @!attribute level
  #         #   The log level (INFO, WARN, ERROR, etc.).
  #         #   @return [String]
  #
  #         # @!attribute text
  #         #   The text of the log message.
  #         #   @return [String]
  #
  #         # Just here to force Yard to create documentation.
  #         # @!visibility private
  #         def initialize; end
  #       end
  #     end
  #   end

  # Components.
  module Components
    # @!visibility private
    module Log
      # @!visibility private
      module Extensions
        # @!visibility private
        module LogExtension
          # @!visibility private
          def self.extended(base_data)
            base_data.data_object ||= {'timestamp' => 0, 'level' => 'INFO', 'text' => ''}
          end

          # @!visibility private
          def timestamp; data_object['timestamp']; end
          # @!visibility private
          def timestamp=(new_timestamp); data_object['timestamp'] = new_timestamp; end
          # @!visibility private
          def level; data_object['level']; end
          # @!visibility private
          def level=(new_level); data_object['level'] = new_level; end
          # @!visibility private
          def text; data_object['text']; end
          # @!visibility private
          def text=(new_text); data_object['text'] = new_text; end
        end
      end

      # @!visibility private
      SCHEMA_DIRECTORY = ::File.expand_path(::File.join(::File.dirname(__FILE__), '..', '..', '..', 'schema'))

      # @!visibility private
      SCHEMA_FILES = {
        'log.avsc' => 'RFlow::Message::Data::Log',
      }

      SCHEMA_FILES.each do |file_name, data_type_name|
        schema_string = ::File.read(::File.join(SCHEMA_DIRECTORY, file_name))
        RFlow::Configuration.add_available_data_type data_type_name, 'avro', schema_string
      end

      RFlow::Configuration.add_available_data_extension('RFlow::Message::Data::Log',
                                                        RFlow::Components::Log::Extensions::LogExtension)
    end
  end
end
