class RFlow
  module Components
    module Raw
      module Extensions
        module RawExtension
          def self.extended(base_data)
            base_data.data_object ||= {'raw' => ''}
          end

          def raw; data_object['raw']; end
          def raw=(new_raw); data_object['raw'] = new_raw; end
        end
      end

      SCHEMA_DIRECTORY = ::File.expand_path(::File.join(::File.dirname(__FILE__), '..', '..', '..', 'schema'))

      SCHEMA_FILES = {
        'raw.avsc' => 'RFlow::Message::Data::Raw',
      }

      SCHEMA_FILES.each do |file_name, data_type_name|
        schema_string = ::File.read(::File.join(SCHEMA_DIRECTORY, file_name))
        RFlow::Configuration.add_available_data_type data_type_name, 'avro', schema_string
      end

      RFlow::Configuration.add_available_data_extension('RFlow::Message::Data::Raw',
                                                        RFlow::Components::Raw::Extensions::RawExtension)
    end
  end
end
