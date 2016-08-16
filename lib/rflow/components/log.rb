class RFlow
  module Components
    module Log
      module Extensions
        module LogExtension
          def self.extended(base_data)
            base_data.data_object ||= {'timestamp' => 0, 'level' => 'INFO', 'text' => ''}
          end

          def timestamp; data_object['timestamp']; end
          def timestamp=(new_timestamp); data_object['timestamp'] = new_timestamp; end
          def level; data_object['level']; end
          def level=(new_level); data_object['level'] = new_level; end
          def text; data_object['text']; end
          def text=(new_text); data_object['text'] = new_text; end
        end
      end

      SCHEMA_DIRECTORY = ::File.expand_path(::File.join(::File.dirname(__FILE__), '..', '..', '..', 'schema'))

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
