class RFlow
  # @!parse
  #   class Message
  #     class Data
  #       # RFlow format defined for raw-data messages which can be emitted by components.
  #       # Of course the real class is {RFlow::Message}
  #       # with type +RFlow::Message::Data::Raw+.
  #       class Raw
  #         # @!attribute raw
  #         #   The raw data.
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
    module Raw
      # @!visibility private
      module Extensions
        # @!visibility private
        module RawExtension
          # @!visibility private
          def self.extended(base_data)
            base_data.data_object ||= {'raw' => ''}
          end

          # @!visibility private
          def raw; data_object['raw']; end
          # @!visibility private
          def raw=(new_raw); data_object['raw'] = new_raw; end
        end
      end

      # @!visibility private
      SCHEMA_DIRECTORY = ::File.expand_path(::File.join(::File.dirname(__FILE__), '..', '..', '..', 'schema'))

      # @!visibility private
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
